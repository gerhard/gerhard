package kubehuddle

import (
	"strings"
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"github.com/gerhard/kubehuddle22/civo"
	"universe.dagger.io/docker"
	"universe.dagger.io/x/david@rawkode.dev/kubernetes:kubectl"
)

dagger.#Plan & {
	client: {
		env: {
			CIVO_API_KEY:      dagger.#Secret
			NAME:              string | *"kubehuddle"
			FQDN:              string | *"kubehuddle.gerhard.io"
			DOCKER_HOST:       string
			REGISTRY_USERNAME: string | *"gerhard"
			REGISTRY_PASSWORD: dagger.#Secret
		}
		filesystem: {
			"./.kubeconfig.yml": write: contents: actions.k8s_config.export.files["/k8s.yml"]
			"./bootstrap": read: contents:        dagger.#FS
			"./app/html": read: contents:         dagger.#FS
			"./app/nginx": read: contents:        dagger.#FS
			"./app/yaml": {
				read: contents:  dagger.#FS
				write: contents: actions.app.manifest.yaml.export.directories["/yaml"]
			}
		}
	}

	actions: {
		// Create a K8s cluster
		k8s: civo.#K8S.create & {
			apiKey:      client.env.CIVO_API_KEY
			clusterName: client.env.NAME
		}

		// Get K8s config
		k8s_config: civo.#K8S.config & {
			// Requires this K8s cluster to exist
			env: MUST_EXIST: "\(k8s.success)"
			apiKey:      k8s.apiKey
			clusterName: k8s.clusterName
		}

		// Get K8s public IP
		k8s_ip: civo.#K8S.ip & {
			// Requires this K8s cluster to exist
			env: MUST_EXIST: "\(k8s.success)"
			apiKey:      k8s.apiKey
			clusterName: k8s.clusterName
		}

		// Configure K8s DNS external-dns not ready yet (Sept. 29, 2022):
		// https://github.com/kubernetes-sigs/external-dns/pull/2852
		k8s_dns: {
			domain: civo.#Domain.create & {
				apiKey: k8s.apiKey
				fqdn:   client.env.FQDN
			}
			record: civo.#Domain.record & {
				// Requires a K8s cluster IP
				env: MUST_EXIST: "\(k8s_ip.success)"
				apiKey: k8s.apiKey
				fqdn:   client.env.FQDN
				record: "*"
				value:  strings.TrimSpace(k8s_ip.export.files["/public_ip.txt"])
				type:   "A"
			}
		}

		// Boostrap K8s cluster
		k8s_bootstrap: {
			_kubeconfig: core.#NewSecret & {
				input: k8s_config.export.rootfs
				path:  "/k8s.yml"
			}
			kubectl.#Apply & {
				manifests:        client.filesystem."./bootstrap".read.contents
				kubeconfigSecret: _kubeconfig.output
			}
		}

		// Create app
		app: {
			// https://github.com/chainguard-images/nginx
			_appBaseImage: "cgr.dev/chainguard/nginx:1.22@sha256:bae2f500050d450b1d3f309bc357c1b61830607f86d5c60249e3665fa433da7f"
			verify:        docker.#Build & {
				steps: [
					docker.#Pull & {
						// https://github.com/sigstore/cosign/pkgs/container/cosign%2Fcosign
						// -> https://github.com/sigstore/cosign/issues/2298
						// https://console.cloud.google.com/gcr/images/projectsigstore/global/cosign
						source: "gcr.io/projectsigstore/cosign:v1.12.1@sha256:ac8e08a2141e093f4fd7d1d0b05448804eb3771b66574b13ad73e31b460af64d"
					},
					docker.#Run & {
						env: COSIGN_EXPERIMENTAL: "1"
						command: {
							name: "verify"
							args: [_appBaseImage]
						}
					},
				]
			}
			build: docker.#Build & {
				steps: [
					docker.#Pull & {
						source: _appBaseImage
					},
					docker.#Copy & {
						contents: client.filesystem."./app/html".read.contents
						dest:     "/var/lib/nginx/html"
					},
					docker.#Copy & {
						contents: client.filesystem."./app/nginx".read.contents
						dest:     "/etc/nginx"
					},
				]
			}
			publish: docker.#Push & {
				image: build.output
				dest:  "ghcr.io/gerhard/kubehuddle22"
				auth: {
					username: client.env.REGISTRY_USERNAME
					secret:   client.env.REGISTRY_PASSWORD
				}
			}
			manifest: {
				// ALT: https://garethr.dev/2019/04/configuring-kubernetes-with-cue/
				_image: docker.#Build & {
					steps: [
						docker.#Pull & {
							// https://hub.docker.com/r/mikefarah/yq/tags
							source: "mikefarah/yq:4.27.5"
						},
						docker.#Copy & {
							contents: client.filesystem."./app/yaml".read.contents
							dest:     "/yaml"
						},
					]
				}
				yaml: docker.#Run & {
					input:   _image.output
					workdir: "/yaml"
					user:    "root"
					command: {
						name: "--inplace"
						args: [
							".spec.template.spec.containers[0].image = \"\(publish.result)\"",
							"deployment.yaml",
						]
					}
					export: directories: "/yaml": dagger.#FS
				}
			}
		}
	}
}