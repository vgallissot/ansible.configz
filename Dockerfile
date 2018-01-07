FROM ansible/ansible:fedora26py3

RUN dnf install ansible-lint yum -y
