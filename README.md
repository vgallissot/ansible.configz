# ansible.configz

Ansible repo to apply my configz:
* aliases,
* zsh,
* liquidprompt,
* fzf,
* GOPATH

### How to use

You can safely run `make` to see what you can do.  
Here are some examples:  

1. Run all playbooks and tests in a docker container
`make run-docker`

2. Run all playbooks without extra tests in a docker container
```
make docker
cd ansible/ansible.configz
make all-playbooks
```

3. Run all playbooks on localhost
`make all-playbooks`

4. Run all playbooks on localhost but change one of defined vars
`make all-playbooks OPTS="--extra-vars '{"zsh_users": ["root", "vincent"]}'"`
