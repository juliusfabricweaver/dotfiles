-- Shared state: the one open review (or nil) and the configuration.
return {
  cur = nil,
  config = {
    default_base = "develop",
    fallback_bases = { "main", "master" },
    sidebar_width = 36,
    large_diff = 1000, -- files with more changed lines start collapsed
    context_step = 20, -- lines revealed by one "expand"
    max_file_bytes = 1024 * 1024, -- bigger files get no context expansion or syntax
  },
}
