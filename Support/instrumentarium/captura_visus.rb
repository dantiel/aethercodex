# frozen_string_literal: true

# CapturaVisus — The Hermetic Screenshot Provider
# Captures visual truth from the screen-plane for AI inspection.
# macOS-first with a clean abstraction surface for future backends.

require 'fileutils'
require 'json'
require 'timeout'
require 'open3'

module CapturaVisus
  DEFAULT_FORMAT = 'jpg'
  DEFAULT_DIR    = File.join '/tmp', 'aethercodex_capturae'
  CAPTURE_BIN    = '/usr/sbin/screencapture'

  # ── Public API ────────────────────────────────────────────────────────────

  def self.capture(mode:,
                   display: nil,
                   x: nil,
                   y: nil,
                   width: nil,
                   height: nil,
                   format: DEFAULT_FORMAT,
                   delay: 0,
                   cursor: true,
                   shadow: true,
                   output: nil,
                   dismiss_dialogs: false)
    # Special case: info mode returns system intel instead of capturing
    return gather_system_info if mode.to_s == 'info'
    
    ensure_dir!
    
    # For window/active-app modes, check for TCC permission dialogs that
    # would obscure freshly-compiled apps. Fall back to screen capture.
    windowed_modes = %w[window active-app]
    tcc_dialogs = windowed_modes.include?(mode.to_s) ? detect_tcc_dialogs : []
    
    if tcc_dialogs.any? && dismiss_dialogs
      dismiss_tcc_dialogs
      tcc_dialogs = [] # retry after dismissal
      sleep 0.5      # let UI settle
    end
    
    if tcc_dialogs.any?
      # Fall back: capture full screen so the agent sees the dialog in context
      actual_mode = 'screen'
      tcc_warning = "TCC permission dialog(s) detected: #{tcc_dialogs.map { |d| d[:title] }.join(', ')}. " \
                    "Fell back to screen capture. The target app may need permissions granted. " \
                    "Use dismiss_dialogs: true to auto-dismiss (clicks 'Deny' on each)."
    else
      actual_mode = mode.to_s
      tcc_warning = nil
    end
    
    path = output || generate_path(format)
    args = build_args(mode: actual_mode, display:, x:, y:, width:, height:,
                      format:, cursor:, shadow:)
    run_capture(path, args, delay:)
    verify! path
    result = { path:, bytes: File.size(path), format:, mode: actual_mode }
    result[:tcc_warning] = tcc_warning if tcc_warning
    result
  rescue StandardError => e
    { error: e.message }
  end

  # ── Backend: screencapture CLI ────────────────────────────────────────────

  def self.build_args(mode:,
                      display:,
                      x:,
                      y:,
                      width:,
                      height:,
                      format:,
                      cursor:,
                      shadow:)
    args = []

    case mode.to_s
    when 'info'
      # Special mode: returns system info instead of capturing
      return gather_system_info
    when 'screen'
      # entire display — no extra flags needed
    when 'window'
      # Use -R with frontmost window bounds (non-interactive) instead of -w
      # -w enters interactive window selection mode requiring a user click
      bounds = frontmost_app_bounds
      raise 'could not determine frontmost window bounds' unless bounds

      args += ['-R', bounds]
    when 'area'
      raise 'area mode requires x,y,width,height' unless x && y && width && height

      args += ['-R', "#{x},#{y},#{width},#{height}"]
    when 'display'
      raise 'display mode requires display number' unless display

      args += ['-D', display.to_s]
    when 'active-app'
      bounds = frontmost_app_bounds
      raise 'could not determine frontmost app bounds' unless bounds

      args += ['-R', bounds]
    when 'menu-bar'
      bounds = menu_bar_bounds
      args += ['-R', bounds] if bounds
    else
      raise "unknown mode: #{mode}"
    end

    args << '-x' # silent — no camera shutter sound
    args << '-C' if cursor
    args << '-o' unless shadow # window shadow off
    args << "-t#{format}" if format

    args
  end


  def self.run_capture(path, args, delay:)
    cmd = [CAPTURE_BIN, *args, path].compact.join(' ')
    sleep delay if delay.positive?
    stdout, stderr, status = Open3.capture3 cmd
    raise "screencapture failed: #{stderr.strip}" unless status.success?

    true
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  def self.generate_path(format)
    ts = Time.now.strftime '%Y%m%d_%H%M%S_%L'
    File.join DEFAULT_DIR, "captura_#{ts}.#{format}"
  end


  def self.ensure_dir!
    FileUtils.mkdir_p DEFAULT_DIR
  end


  def self.verify!(path)
    raise "no file at #{path}" unless File.exist? path
    raise "empty file at #{path}" if File.empty? path
  end

  # ── macOS geometry via osascript ──────────────────────────────────────────

  def self.frontmost_app_bounds
    script = <<~APPLESCRIPT
      tell application "System Events"
        set frontApp to first application process whose frontmost is true
        set winPos to position of window 1 of frontApp
        set winSize to size of window 1 of frontApp
        set x1 to item 1 of winPos
        set y1 to item 2 of winPos
        set x2 to item 1 of winSize
        set y2 to item 2 of winSize
        return (x1 as text) & "," & (y1 as text) & "," & (x2 as text) & "," & (y2 as text)
      end tell
    APPLESCRIPT
    run_osascript script
  end


  def self.menu_bar_bounds
    script = <<~APPLESCRIPT
      tell application "System Events"
        tell process "SystemUIServer"
          get bounds of menu bar 1
        end tell
      end tell
    APPLESCRIPT
    run_osascript script
  end


  def self.run_osascript(script)
    out, _stderr, status = Open3.capture3 'osascript', '-e', script
    return nil unless status.success?

    cleaned = out.strip.gsub ', ', ','
    cleaned.empty? ? nil : cleaned
  rescue StandardError
    nil
  end

  # ── Info Mode: Gather System Intel ─────────────────────────────────────────

  def self.gather_system_info
    info = {
      timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z'),
      platform: 'macOS',
      system: gather_system_hardware,
      displays: gather_displays_cg,
      frontmost_app: gather_frontmost_app,
      visible_windows: gather_windows_cg,
      menu_bar: gather_menu_bar_info,
      permissions: check_permissions,
      tcc_dialogs: detect_tcc_dialogs,
      suggestions: generate_suggestions
    }
    
    begin
      HorologiumAeternum.tool_call('system', 'info_gathered',
        "Gathered system intel: #{info[:displays].length} display(s), " \
        "#{info[:visible_windows].length} window(s), #{info[:frontmost_app][:name]}")
    rescue NameError
      # HorologiumAeternum not loaded (standalone test)
    end
    
    info
  end

  # Display detection via system_profiler + screen_capture
  def self.gather_displays_cg
    displays = gather_displays_system_profiler
    return displays unless displays.empty?
    
    fallback_displays
  rescue StandardError
    fallback_displays
  end

  def self.gather_displays_system_profiler
    begin
      # Parse Display info from system_profiler in JSON format
      out, err, status = Open3.capture3(
        'system_profiler', '-json', 'SPDisplaysDataType',
        'SPHardwareDataType'
      )
      
      return [] unless status.success?
      
      require 'json'
      data = JSON.parse(out)
      
      displays = []
      gpu_data = data['SPDisplaysDataType'] || []
      
      # Each GPU entry contains displays in spdisplays_ndrvs
      display_id = 0
      gpu_data.each do |gpu|
        gpu_name = gpu['_name']
        gpu_vendor = gpu['spdisplays_vendor']
        
        # Get displays array from GPU (Apple Silicon: ndrvs, Intel: direct)
        display_entries = gpu['spdisplays_ndrvs'] || [gpu]
        
        display_entries.each do |disp|
          display_id += 1
          
          # Display name
          name = disp['_name'] || "Display #{display_id}"
          
          # Resolution
          resolution = disp['_spdisplays_resolution'] || disp['_spdisplays_pixels'] || 'unknown'
          
          # Parse pixels (raw native resolution)
          pixels = disp['_spdisplays_pixels'].to_s
          pixel_match = pixels.match(/(\d+)\s*x\s*(\d+)/)
          native_w = pixel_match ? pixel_match[1].to_i : nil
          native_h = pixel_match ? pixel_match[2].to_i : nil
          
          # Parse visible resolution
          res_match = resolution.to_s.match(/(\d+)\s*x\s*(\d+)/)
          width = res_match ? res_match[1].to_i : nil
          height = res_match ? res_match[2].to_i : nil
          
          # Connection type
          connection = disp['spdisplays_connection_type'] || 'unknown'
          is_builtin = connection == 'spdisplays_internal' ||
                       disp['spdisplays_display_type']&.include?('built-in')
          
          # Is main display
          is_main = disp['spdisplays_main'] == 'spdisplays_yes'
          
          # Display type classification
          display_type = if disp['spdisplays_display_type']
                          case disp['spdisplays_display_type']
                          when /retina/ then 'Retina'
                          when /lcd/ then 'LCD'
                          else 'External'
                          end
                        elsif is_builtin
                          'Built-in'
                        else
                          'External'
                        end
          
          displays << {
            id: display_id,
            name: name,
            resolution: resolution,
            native_resolution: native_w && native_h ? "#{native_w}x#{native_h}" : nil,
            width: width,
            height: height,
            refresh_rate: resolution[/@\s*([\d.]+)/, 1],
            is_builtin: is_builtin,
            is_main: is_main,
            display_type: display_type,
            connection: connection.to_s.gsub('spdisplays_', ''),
            # Bounds (approximate for positioning)
            bounds: {
              x: is_main ? 0 : (width || 1920),
              y: 0,
              width: width || 1920,
              height: height || 1080
            },
            gpu: gpu_name
          }
        end
      end
      
      displays
    rescue StandardError => e
      []
    end
  end

  def self.fallback_displays
    begin
      require 'cocoaf'
      NSScreen.screens.map.with_index do |screen, i|
        frame = screen.frame
        backing = screen.backingScaleFactor
        {
          id: i + 1,
          bounds: {
            x: frame.origin.x.to_i,
            y: frame.origin.y.to_i,
            width: frame.size.width.to_i,
            height: frame.size.height.to_i
          },
          resolution: "#{(frame.size.width * backing).to_i}x#{(frame.size.height * backing).to_i}",
          scale: backing,
          is_main: (i == 0)
        }
      end
    rescue LoadError
      # Final fallback
      [{
        id: 1,
        bounds: { x: 0, y: 0, width: 1920, height: 1080 },
        resolution: 'unknown',
        note: 'Fell back to defaults - install cocoaf gem for better detection'
      }]
    end
  end

  # CoreGraphics window list (no permissions needed)
  def self.gather_windows_cg
    begin
      require 'fiddle'
      
      cg = Fiddle.dlopen('/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics')
      
      # CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID)
      kCGWindowListOptionOnScreenOnly = 2
      kCGNullWindowID = 0
      
      cg_window_list = cg['CGWindowListCopyWindowInfo']
      window_list = cg_window_list.call(kCGWindowListOptionOnScreenOnly, kCGNullWindowID)
      
      return [] if window_list == 0
      
      # Convert CFArrayRef to Ruby array via toll-free bridging
      require 'cfpropertylist'
      plist = CFPropertyList::List.new(data: Fiddle::Pointer.new(window_list).to_str(65536))
      window_data = CFPropertyList.native_types(plist.value)
      
      window_data.map do |win|
        bounds = win['kCGWindowBounds'] || {}
        {
          pid: win['kCGWindowOwnerPID'],
          app: win['kCGWindowOwnerName'],
          title: win['kCGWindowName'],
          alpha: win['kCGWindowAlpha'],
          layer: win['kCGWindowLayer'],
          bounds: {
            x: bounds['X'],
            y: bounds['Y'],
            width: bounds['Width'],
            height: bounds['Height']
          },
          is_onscreen: win['kCGWindowIsOnscreen']
        }
      end.compact.first(20) # Limit to avoid huge payloads
    rescue StandardError => e
      # Fallback to System Events
      gather_visible_windows
    end
  end

  def self.gather_system_hardware
    begin
      # Hardware info via system_profiler
      out, _err, status = Open3.capture3('system_profiler', '-json', 'SPHardwareDataType', 'SPDisplaysDataType')
      
      if status.success?
        require 'json'
        data = JSON.parse(out)
        
        hardware = data['SPHardwareDataType']&.first || {}
        displays = data['SPDisplaysDataType'] || []
        
        # Get chip from GPU info if cpu_type shows "Unknown"
        chip = hardware['chip_type']
        if chip.nil? || chip == 'Unknown'
          # Try to get from display GPU info
          first_gpu = displays.first
          chip = first_gpu&.dig('sppci_model') || hardware['cpu_type'] || 'Unknown'
        end
        
        {
          model: hardware['machine_model'],
          model_name: hardware['machine_name'],
          chip: chip,
          memory: hardware['physical_memory'],
          serial: hardware['serial_number']&.slice(0, 4).to_s + '...', # Partial for privacy
          processor: hardware['number_processors'],
          os_version: `sw_vers -productVersion 2>/dev/null`.strip,
          os_build: `sw_vers -buildVersion 2>/dev/null`.strip,
          uptime: `uptime 2>/dev/null`.strip,
          display_count: displays.length
        }
      else
        { error: 'system_profiler failed', status: status.exitstatus }
      end
    rescue StandardError => e
      { error: e.message }
    end
  end

  def self.check_permissions
    # Check Accessibility permission status
    script = <<~'APPLESCRIPT'
     tell application "System Events"
        return "granted"
      on error
        return "denied"
      end try
    end tell
    APPLESCRIPT
    
    accessibility = run_osascript(script) || 'unknown'
    
    # Screen recording permission: try a 1x1 capture and check for TCC denial
    screen_recording = check_screen_recording_permission
    
    tips = []
    tips << 'Grant Accessibility in System Settings > Privacy & Security > Accessibility for TextMate' if accessibility == 'denied'
    tips << 'Grant Screen Recording in System Settings > Privacy & Security > Screen Recording for TextMate' if screen_recording != 'granted'
    
    {
      accessibility: accessibility,
      system_events_available: accessibility != 'denied',
      screen_recording: screen_recording,
      tips: tips.empty? ? nil : tips.join('; ')
    }
  end
  
  # Test screencapture with a 1x1 pixel at 0,0 to probe TCC status
  def self.check_screen_recording_permission
    probe = File.join(DEFAULT_DIR, '.perm_probe.jpg')
    _stdout, stderr, status = Open3.capture3('/usr/sbin/screencapture', '-R', '0,0,1,1', '-x', '-tjpg', probe)
    FileUtils.rm_f(probe) if File.exist?(probe)
    
    if status.success?
      'granted'
    elsif stderr.match?(/not (?:be )?permitted|not authorized|cannot be used|TCC/i)
      'denied'
    else
      'unknown'
    end
  rescue StandardError
    'unknown'
  end

  # ── TCC Permission Dialog Detection & Dismissal ──────────────────────────
  # Detects macOS Transparency, Consent, and Control (TCC) permission dialogs
  # that obscure freshly-compiled apps. These dialogs are presented by system
  # processes and can ruin window/active-app screenshots.

  def self.detect_tcc_dialogs
    script = <<~'APPLESCRIPT'
      tell application "System Events"
        set dialogInfo to {}
        set tccProcessNames to {"UserNotificationCenter", "CoreServicesUIAgent", "loginwindow"}
        repeat with procName in tccProcessNames
          try
            set procWindows to every window of (first process whose name is procName)
            repeat with w in procWindows
              try
                set wTitle to title of w
                if wTitle contains "would like to" or wTitle contains "Would Like to" or wTitle contains "TCC" then
                  set end of dialogInfo to procName & "::" & wTitle
                end if
              end try
            end repeat
          end try
        end repeat
        return dialogInfo
      end tell
    APPLESCRIPT
    result = run_osascript(script)
    return [] unless result

    result.split(',').map do |entry|
      parts = entry.split('::')
      next if parts.length < 2
      { process: parts[0].strip, title: parts[1].strip }
    end.compact
  rescue StandardError
    []
  end

  def self.dismiss_tcc_dialogs
    script = <<~'APPLESCRIPT'
      tell application "System Events"
        set tccProcessNames to {"UserNotificationCenter", "CoreServicesUIAgent", "loginwindow"}
        repeat with procName in tccProcessNames
          try
            set procWindows to every window of (first process whose name is procName)
            repeat with w in procWindows
              try
                set wTitle to title of w
                if wTitle contains "would like to" or wTitle contains "Would Like to" or wTitle contains "TCC" then
                  -- Click "Deny" button (safe default — permissions can be granted later)
                  try
                    click button "Deny" of w
                  on error
                    -- Fallback: try closing the window
                    try
                      keystroke return
                    end try
                  end try
                end if
              end try
            end repeat
          end try
        end repeat
      end tell
    APPLESCRIPT
    run_osascript(script)
    nil
  rescue StandardError
    nil
  end

  def self.generate_suggestions
    [
      'Use take_screenshot(mode: "area", x: 100, y: 100, width: 800, height: 600) for specific regions',
      'Use take_screenshot(mode: "window") for frontmost window only',
      'Use format: "jpg" for smaller files than png',
      'Full screen: mode: "screen", Single display: mode: "display", Active app: mode: "active-app"',
      'Use delay: 2 to wait for UI changes before capture',
      'For freshly-compiled apps: TCC dialogs are auto-detected; capture falls back to screen mode. Use dismiss_dialogs: true to auto-dismiss (clicks Deny).',
      'Use mode: "info" to check permissions and detect TCC dialogs before capturing'
    ]
  end

  def self.gather_displays
    script = <<~APPLESCRIPT
      tell application "System Events"
        tell application process "Finder"
          set displayData to {}
          set allDisplays to every desktop
          repeat with d in allDisplays
            set dBounds to bounds of d
            set end of displayData to ((x1 of dBounds as string) & "," & (y1 of dBounds as string) & "," & (x2 of dBounds as string) & "," & (y2 of dBounds as string))
          end repeat
          return displayData
        end tell
      end tell
    APPLESCRIPT
    
    # Fallback: use NSScreen via Ruby
    begin
      require 'cocoaf'
      screens = NSScreen.screens
      screens&.map.with_index do |screen, i|
        frame = screen.frame
        {
          id: i + 1,
          bounds: "#{frame.origin.x.to_i},#{frame.origin.y.to_i},#{frame.size.width.to_i},#{frame.size.height.to_i}",
          size: "#{frame.size.width.to_i}x#{frame.size.height.to_i}"
        }
      end
    rescue LoadError
      # Use simpler query
      simpler_script = <<~APPLESCRIPT
        tell application "Finder"
          set screenBounds to bounds of window of desktop
          return (item 1 of screenBounds as string) & "," & (item 2 of screenBounds as string) & "," & (item 3 of screenBounds as string) & "," & (item 4 of screenBounds as string)
        end tell
      APPLESCRIPT
      bounds = run_osascript(simpler_script)
      [{ id: 1, bounds: bounds, size: 'unknown' }]
    end
  end

  def self.gather_frontmost_app
    script = <<~APPLESCRIPT
      tell application "System Events"
        set frontAppName to name of first application process whose frontmost is true
        set frontAppPID to unix id of first application process whose frontmost is true
        try
          set appTitle to name of window 1 of first application process whose frontmost is true
        on error
          set appTitle to "no title"
        end try
        try
          set {x, y, w, h} to bounds of window 1 of first application process whose frontmost is true
          set winBounds to x & "," & y & "," & w & "," & h
        on error
          set winBounds to "none"
        end try
        return {frontAppName, frontAppPID, appTitle, winBounds}
      end tell
    APPLESCRIPT
    
    result = run_osascript(script)
    return { name: 'unknown', pid: nil, title: nil, bounds: nil } unless result
    
    parts = result.split(',').map(&:strip)
    {
      name: parts[0] || 'unknown',
      pid: parts[1]&.to_i,
      title: parts[2] || 'none',
      bounds: parts[3..-1]&.join(',') || 'none'
    }
  end

  def self.gather_visible_windows
    script = <<~APPLESCRIPT
      tell application "System Events"
        set windowList to {}
        set allProcesses to application processes whose background only is false
        repeat with proc in allProcesses
          set procName to name of proc
          set procWindows to every window of proc whose visible is true
          repeat with win in procWindows
            set winName to name of win
            set {x1, y1, x2, y2} to bounds of win
            set winBounds to x1 & "," & y1 & "," & x2 & "," & y2
            set end of windowList to procName & "::" & winName & "::" & winBounds
          end repeat
        end repeat
        return windowList
      end tell
    APPLESCRIPT
    
    result = run_osascript(script)
    return [] unless result
    
    result.split(',').map do |entry|
      parts = entry.split('::')
      next if parts.length < 3
      
      {
        app: parts[0],
        title: parts[1],
        bounds: parts[2]
      }
    end.compact.first(10) # Limit to avoid huge payloads
  end

  def self.gather_menu_bar_info
    {
      bounds: menu_bar_bounds,
      height: 24 # Standard macOS menu bar height
    }
  end

  # ── Future backends (stubs for extensibility) ─────────────────────────────

  def self.providers
    %i[screencapture avfoundation coregraphics simulator ios android]
  end
end