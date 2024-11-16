# Terraform Module for Deploying Red5 Pro in Linode Cloud - Stream Manager 2.0

[Red5 Pro](https://www.red5.net/) is a real-time video streaming server plaform known for its low-latency streaming capabilities, making it ideal for interactive applications like online gaming, streaming events and video conferencing etc.

This is a reusable Terraform module that provisions infrastructure on [Linode Cloud](https://www.linode.com/).

## Preparation

### Install Terraform

- Visit the [Terraform download page](https://developer.hashicorp.com/terraform/downloads) and ensure you get version 1.7.5 or higher.
- Download the suitable version for your operating system.
- Extract the compressed file and copy the Terraform binary to a location within your system's PATH.
- Configure PATH for **Linux/macOS**:
  - Open a terminal and type the following command:

    ```sh
    sudo mv /path/to/terraform /usr/local/bin
    ```

- Configure PATH for **Windows**:
  - Click 'Start', search for 'Control Panel', and open it.
  - Navigate to `System > Advanced System Settings > Environment Variables`.
  - Under System variables, find 'PATH' and click 'Edit'.
  - Click 'New' and paste the directory location where you extracted the terraform.exe file.
  - Confirm changes by clicking 'OK' and close all open windows.
  - Open a new terminal and verify that Terraform has been successfully installed.

  ```sh
  terraform --version
  ```

### Install jq

- Install **jq** (Linux or Mac OS only) [Download](https://jqlang.github.io/jq/download/)
  - Linux: `apt install jq`
  - MacOS: `brew install jq`
  > It is used in bash scripts to create/delete Stream Manager node group using API

### Red5 Pro artifacts

- Download Red5 Pro server build in your [Red5 Pro Account](https://account.red5.net/downloads). Example: `red5pro-server-0.0.0.b0-release.zip`
- Get Red5 Pro License key in your [Red5 Pro Account](https://account.red5.net/downloads). Example: `1111-2222-3333-4444`

### Install Linode Cloud CLI

### Prepare Linode Cloud account
