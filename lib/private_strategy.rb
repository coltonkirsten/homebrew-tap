# typed: false
# frozen_string_literal: true

require "download_strategy"
require "json"
require "net/http"

# Downloads a release asset of a private GitHub repo through the API, authenticated with HOMEBREW_GITHUB_API_TOKEN
# (a token that can read the repo). The token is sent only to api.github.com, never to the redirect target.
class GitHubPrivateRepositoryReleaseDownloadStrategy < CurlDownloadStrategy
  URL_PATTERN = %r{\Ahttps://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/([^/?]+)\z}

  def fetch(timeout: nil)
    if cached_location.exist?
      puts "Already downloaded: #{cached_location}"
    else
      match = URL_PATTERN.match(url)
      raise CurlDownloadStrategyError.new(url, "not a GitHub release asset URL") unless match

      owner, repo, tag, filename = match.captures
      token = ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "")
      if token.empty?
        raise CurlDownloadStrategyError.new(url,
          "set HOMEBREW_GITHUB_API_TOKEN to a GitHub token that can read #{owner}/#{repo}")
      end

      ohai "Downloading #{filename} from the private release #{owner}/#{repo}@#{tag}"
      release_uri = URI("https://api.github.com/repos/#{owner}/#{repo}/releases/tags/#{tag}")
      release = JSON.parse(api_get(release_uri, token, "application/vnd.github+json"))
      asset = release.fetch("assets", []).find { |a| a["name"] == filename }
      raise CurlDownloadStrategyError.new(url, "release #{tag} has no asset #{filename}") unless asset

      body = api_get(URI(asset.fetch("url")), token, "application/octet-stream")
      temporary_path.dirname.mkpath
      File.binwrite(temporary_path, body)
      cached_location.dirname.mkpath
      temporary_path.rename(cached_location.to_s)
    end
    create_symlink_to_cached_download(cached_location)
  end

  private

  def api_get(uri, token, accept)
    redirects = 5
    loop do
      req = Net::HTTP::Get.new(uri)
      req["Accept"] = accept
      req["Authorization"] = "Bearer #{token}" if uri.host == "api.github.com"
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
      case res
      when Net::HTTPSuccess then return res.body
      when Net::HTTPRedirection
        redirects -= 1
        raise CurlDownloadStrategyError.new(url, "too many redirects") if redirects.negative?

        uri = URI(res["location"])
      else
        raise CurlDownloadStrategyError.new(url,
          "GET #{uri.host}#{uri.path}: HTTP #{res.code} (does the token have repo access?)")
      end
    end
  end
end
