# coltonkirsten/homebrew-tap (private)

Homebrew formulae for private tools. GoReleaser in each tool's repo writes `Formula/<tool>.rb` on release; don't
edit those by hand.

```sh
export HOMEBREW_GITHUB_API_TOKEN=<token with repo scope>   # downloads the private release assets
brew tap coltonkirsten/tap https://github.com/coltonkirsten/homebrew-tap   # git must be able to read this repo
brew install coltonkirsten/tap/a12s
```

The release assets live in private repos, so `lib/private_strategy.rb` downloads them through the GitHub API with
`HOMEBREW_GITHUB_API_TOKEN`. The token is sent only to api.github.com.

a12s also pulls its images from ghcr.io, which needs `docker login ghcr.io` with a token that has `read:packages`.
