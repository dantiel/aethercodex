


BUNDLE_GEMFILE=Gemfile \
  #TM_DEBUG_PATHS=1 \
  GEM_HOME=.vendor_bundle \
  GEM_PATH=.vendor_bundle \
  TM_QUERY="/Applications/TextMate.app/Contents/MacOS/tm_query" \
  TM_PROJECT_DIRECTORY="$HOME/Library/Application Support/TextMate/Pristine Copy/Bundles/AetherCodex.tmbundle" \
  bundle exec ruby limen.rb
  
  