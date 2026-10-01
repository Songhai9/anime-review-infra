# Architecture diagrams

Every view exists in two levels of detail here: READMEs show the **overview** image (keywords plus one technical line) and fold the **detailed** one inside a `<details>` block. The documentation package also holds a simpler version and "cloud" variants of the AWS views.

| View | Overview | Detailed |
|---|---|---|
| The three repositories and how they hand over to each other | [png](00-overview.png) · [svg](00-overview.svg) | — |
| Phase 2b: containers on AWS virtual machines, CI to servers | [png](02-vm-docker.png) · [svg](02-vm-docker.svg) | [png](02-vm-docker-detailed.png) · [svg](02-vm-docker-detailed.svg) |
| Phase 2a: Node.js on AWS virtual machines, set up by Ansible | [png](02-vm-native.png) · [svg](02-vm-native.svg) | [png](02-vm-native-detailed.png) · [svg](02-vm-native-detailed.svg) |
| Phase 3: private kubeadm cluster on AWS | [png](03-kubernetes.png) · [svg](03-kubernetes.svg) | [png](03-kubernetes-detailed.png) · [svg](03-kubernetes-detailed.svg) |
| Phase 3: infrastructure pipeline, step by step | [png](04-infra-pipeline.png) · [svg](04-infra-pipeline.svg) | [png](04-infra-pipeline-detailed.png) · [svg](04-infra-pipeline-detailed.svg) |
| Phase 3: from git push to production | — | [png](05-delivery-chain-detailed.png) · [svg](05-delivery-chain-detailed.svg) |

**How to read them.** Coloured containers with a tag are boundaries (AWS, subnet, cluster, pipeline). White cards are components, with the technology logo in the window icon. Numbered badges give the order of the steps. Arrow colours: blue = user traffic or delivery, purple = automation / administration, green = data or images, orange = internet access. Dashed = remote command or optional path.

The PNG files are rendered at 2× from the SVG sources; the SVGs render best with Poppins and Inter installed. Diagrams are generated from code (see the documentation package). Technology logos come from [Devicon](https://github.com/devicons/devicon) ([MIT](DEVICON-LICENSE.txt)); AWS service tiles, Helm, NGINX, Ubuntu and Calico marks are simplified redraws. Trademarks belong to their owners.
