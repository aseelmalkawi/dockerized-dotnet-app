# Infrastructure Bootstrap — Ansible Playbook

This playbook configures a fresh Ubuntu EC2 instance provisioned by Terraform. It installs Docker, Nginx, MicroK8s, and the AWS CLI, then validates the cluster is healthy before finishing.

---

## How the Inventory Is Generated

The Ansible inventory is never written by hand and is not committed to the repository. It is generated automatically by Terraform at the end of `terraform apply` using a `local_file` resource:

```hcl
resource "local_file" "inventory" {
  filename = "../Ansible/inventory.yml"
  content  = templatefile("inventory.tpl", {
    server_ip = aws_instance.my_server.public_ip
  })
}
```

Once Terraform knows the EC2 instance's public IP, it writes it into `Ansible/inventory.yml` before Ansible runs. This means the inventory always reflects the actual live infrastructure without any manual intervention.

The SSH private key is never stored in the inventory file or in the repository. It is written from a GitHub Secret to `/tmp/deploy_key` at runtime and referenced by path in the inventory.

---

## Playbook Breakdown

### Play Definition

```yaml
hosts: all
become: true
```

`hosts: all` targets every host in the inventory — in this case one EC2 instance. `become: true` runs every task as root via sudo, which is required for installing packages and managing system services.

---

### Variables

```yaml
vars:
  user_name: "{{ ansible_user }}"
  user_home: "/home/{{ ansible_user }}"
  microk8s_channel: "1.31/stable"
  microk8s_addons:
    - dns
    - registry
    - dashboard
    - istio
```

`ansible_user` is the SSH user defined in the inventory (`ubuntu`). Rather than hardcoding `ubuntu` throughout the playbook, it is captured in `user_name` so the playbook works with any user without edits.

`user_home` is constructed from the username rather than using `~` or a hardcoded path, because tasks running under `become: true` can resolve home directories inconsistently depending on the sudo configuration.

`microk8s_channel` pins MicroK8s to a specific Kubernetes minor version. Without pinning, snap installs the latest available revision.

`microk8s_addons` is defined as a variable for documentation purposes even though only `dns` is currently enabled in tasks. It serves as a reference for what the cluster is intended to support.

---

### System

```yaml
- name: Update and upgrade apt packages
  apt:
    update_cache: yes
    upgrade: dist
    cache_valid_time: 3600
```

Refreshes the apt package index and performs a full distribution upgrade before installing anything. This ensures the instance is not running outdated packages with known vulnerabilities. `cache_valid_time` prevents redundant refreshes if the playbook is re-run within an hour.

```yaml
- name: Install base packages
  apt:
    name: [ca-certificates, curl, gnupg, ...]
    state: present
```

Installs all system-level dependencies in a single apt call to avoid multiple package manager invocations. `nginx` is included here rather than in a separate task for the same reason — fewer apt calls means faster runs.

```yaml
- name: Ensure nginx is enabled and started
  service:
    state: started
    enabled: yes
```

Starting and enabling are kept as a single task because they are logically one operation. `enabled: yes` ensures Nginx survives a reboot, which matters for a persistent dev machine.

---

### Docker

```yaml
- name: Install Docker via official repo
  apt:
    name: docker.io
    state: present
```

Uses `docker.io` from the Ubuntu apt repository rather than the official Docker install script (`curl | sh`). The script approach is convenient but harder to make idempotent and introduces a dependency on an external URL at install time. The apt package is sufficient for a dev machine.

```yaml
- name: Add user to docker group
  user:
    name: "{{ user_name }}"
    groups: docker
    append: yes
```

`append: yes` is critical here. Without it, Ansible replaces all existing group memberships with only `docker`, which would remove the user from `sudo` and lock you out of privilege escalation. This task will not take effect in the current session — the user must log out and back in, which is why the final reminder exists.

---

### MicroK8s

```yaml
- name: Install MicroK8s
  snap:
    name: microk8s
    classic: yes
    state: present
```

`classic: yes` grants MicroK8s access outside the snap sandbox. MicroK8s requires this because it manages kernel-level networking, mounts, and system services that a confined snap cannot reach.

The `channel` is not pinned at the snap module level here because the snap module's channel handling can conflict with an already-installed snap. If the instance is fresh (which it always is when provisioned by Terraform), the default channel is acceptable and the snap is immediately up to date.

```yaml
- name: Add user to microk8s group
  user:
    name: "{{ user_name }}"
    groups: microk8s
    append: yes
  become: true
```

Without this, all `microk8s` and `microk8s kubectl` commands require sudo. Adding the user to the group allows the CI runner and any human operator to use the cluster without elevated privileges after re-login.

```yaml
- name: Wait for Kubernetes API
  command: microk8s kubectl get nodes
  register: kube_check
  retries: 20
  delay: 15
  until: kube_check.rc == 0
```

MicroK8s takes time to fully initialise after installation. The snap is installed synchronously but the Kubernetes control plane components start asynchronously inside it. Without this wait, subsequent tasks like enabling addons will fail with cryptic errors because the API server is not yet accepting requests. 20 retries at 15 second intervals gives up to 5 minutes, which is enough for any normal instance type.

```yaml
- name: Validate cluster nodes
  command: microk8s kubectl get nodes
  retries: 5
  delay: 10
  until: node_check.rc == 0
```

A second, shorter validation after the initial wait. This confirms the node has fully registered with the API and is in a ready state before addons are enabled. Enabling addons against a partially ready cluster can cause them to get stuck in a pending state indefinitely.

```yaml
- name: Enable dns addon
  command: microk8s enable dns
  register: dns_result
  changed_when: "'already enabled' not in dns_result.stdout"
```

`dns` is the only addon enabled here because it is the only one required for basic cluster operation. Without it, pods cannot resolve service names and most workloads will fail silently. `changed_when` prevents Ansible from reporting a change on re-runs where dns is already enabled, keeping the output clean and idempotent.

```yaml
- name: Wait for dns to be ready
  command: microk8s kubectl rollout status deployment/coredns -n kube-system
  retries: 10
  delay: 10
  until: dns_check.rc == 0
```

Enabling an addon is asynchronous. The `microk8s enable` command returns immediately but CoreDNS pods take time to pull images and start. This task blocks until the CoreDNS deployment has fully rolled out, ensuring the cluster is actually usable when the playbook finishes.

---

### AWS CLI

```yaml
- name: Check if AWS CLI is installed
  command: aws --version
  register: aws_check
  changed_when: false
  failed_when: false
```

`failed_when: false` prevents Ansible from stopping if `aws` is not found. The return code is stored in `aws_check.rc` and used as a condition on every subsequent AWS CLI task. `changed_when: false` ensures a check command never incorrectly reports a change.

```yaml
- name: Install AWS CLI
  command: /tmp/aws/install
  args:
    creates: /usr/local/bin/aws
```

`creates` tells Ansible to skip this task if `/usr/local/bin/aws` already exists. This is a belt-and-suspenders guard on top of the `aws_check` condition — if the binary is present from a previous run that the check missed, the installer is still skipped.

```yaml
- name: Cleanup AWS CLI installer
  file:
    path: "{{ item }}"
    state: absent
  loop:
    - /tmp/aws
    - /tmp/awscliv2.zip
```

The installer zip and extracted directory are removed after installation. Left in place, they consume several hundred MB of disk on every instance.

---

### Final Reminder

```yaml
- name: Reminder about group membership
  debug:
    msg: >
      Installation complete. Log out and log back in for docker and microk8s
      group membership to apply.
```

Group membership changes applied by the `user` module take effect only when the user starts a new login session. The current SSH session retains the old group list. This reminder exists because forgetting this is a common source of confusion — running `docker ps` immediately after the playbook finishes will still return a permission error until the user reconnects.