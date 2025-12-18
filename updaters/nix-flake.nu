def "rad update nix-flake" [] {
  print -e "updating nix flake inputs"
  nix flake update --commit-lock-file
}
