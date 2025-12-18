def "rad update cargo" [] {
  print -e "updating cargo dependencies"
  cargo upgrade -i
  cargo update
  if (git diff -s --exit-code | complete | $in.exit_code == 1) {
    git commit -a -m "chore: update dependencies"
  }
}
