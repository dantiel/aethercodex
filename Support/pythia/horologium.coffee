###
Horologium - Hierarchical File Overview Rendering
Enhances file overview display with proper hierarchical visualization
###
class Horologium
  constructor: ->
    @hierarchyData = null
    @expandedNodes = new Set
    @pythia = window.pythia


  # Render hermetic overview section for celestial pattern visibility
  renderHermeticOverview: (hermetic_data) ->
    return '' unless hermetic_data
    
    # Handle both string format and array format
    if 'string' is typeof hermetic_data 
      hermetic_data = hermetic_data.split '\n'
    
    return '' unless hermetic_data.length
    
    html = """
      <div class="hermetic-overview-preview">
        <details>
          <summary>⚡️ Hermetic Overview</summary>
          <div class="hermetic-patterns">
    """
    
    hermetic_data.forEach (pattern) =>
      # Parse pattern format: "file>tag*count,tag*count"
      if pattern.includes '>'
        [file_part, tags_part] = pattern.split '>'
        tags = tags_part.split ','
        
        file_html = if @pythia && file_part 
          match_file_name = /^\/?(.+\/)*(.+?)(\.(.+))?$/
          link_href = @pythia.createTextMateLink file_part
          [_, file_path = '', file_name] = file_part.match match_file_name
          """<a href="#{link_href}"  class="file-link">
            #{file_path} <strong>📄 #{file_name}</strong></a>"""
        else if file_part 
          "<strong>#{@pythia. file_part}</strong>" 
        else ''
        
        tags_html = tags.map (tag) =>
          if tag.includes '*'
            [tag_name, count] = tag.split '*'
            """<span class='hermetic-tag' title='#{tag_name}'>
                 #{tag_name}<small>#{count}</small></span>"""
          else
            "<span class='hermetic-tag'>#{tag}</span>"
        .join ''
        
        html += """
          <div class="hermetic-pattern">
            #{file_html}#{tags_html}
          </div>
        """
    
    html += """
          </div>
        </details>
      </div>
    """
    
    return html


  renderFileOverview: (fileData) ->
    result_data = fileData.data || fileData
    file_info = result_data.file_info || result_data.data?.file_info || {}

    symbolic_data = result_data.symbolic_overview || result_data.data?.symbolic_overview || result_data
    { imports, exports } = symbolic_data
    
    # Handle the case where data is nested under result.data
    if result_data.data
      file_info = result_data.data.file_info || file_info
      symbolic_data = result_data.data.symbolic_overview || symbolic_data
    
    # Handle deeply nested data structure: data.result.data.data.file_info
    if result_data.result?.data?.file_info
      file_info = result_data.result.data.file_info
      symbolic_data = result_data.result.data.symbolic_overview || symbolic_data

    language = symbolic_data.language || symbolic_data.structural_summary?.language || 'unknown'
    lines = file_info.lines || symbolic_data.lines || 0
    size = if file_info.size then @formatFileSize(file_info.size) else '0B'
    containers = symbolic_data.structural_summary?.containers || symbolic_data.structure?.containers || 0
    members = symbolic_data.structural_summary?.members || symbolic_data.structure?.members || 0
    
    # Get comprehensive statistics from structure data
    structure = symbolic_data.structure || symbolic_data.structural_summary || {}
    import_count = structure.import_count || imports.length
    export_count = structure.export_count || exports.length
    symbol_count = structure.symbol_count || (symbolic_data.symbols?.length || 0)
    variables = structure.variables || 0
    
    overview_html = """
      <div class="file-overview-status">
        <div class="file-overview-header">
          <span class="language-badge">#{language}</span>
          <span class="line-count">#{lines} lines</span>
          <span class="file-size">#{size}</span>
        </div>
        <div class="structure-summary">
          #{containers} containers, #{members} members,
          #{import_count} imports, #{export_count} exports,
          #{symbol_count} symbols, #{variables} variables
        </div>
    """
    
    # Add hierarchy if available - handle both flat and nested structures
    hierarchy = symbolic_data.hierarchy || file_info.hierarchy
    
    # If hierarchy is empty but we have structural data, try to build it
    if (!hierarchy || hierarchy.length == 0) && symbolic_data.structural_summary
      hierarchy = @buildHierarchyFromStructuralData(symbolic_data)
    
    if hierarchy?.length
      overview_html += """
        <div class="hierarchy-preview">
          <details>
            <summary>🌳 Hierarchical Structure</summary>
            <div class="hierarchy-tree-preview">
              #{@renderHierarchyPreview(hierarchy, symbolic_data, 0, file_info)}
            </div>
          </details>
        </div>
      """
    
    # Add imports/exports if available
    imports = symbolic_data.imports || file_info.imports || []
    exports = symbolic_data.exports || file_info.exports || []
    if imports?.length || exports?.length
      renderImportExport = (items, type) ->
        if items?.length
          itemsHtml = items.map (item) ->
            typeLabel = if item.type then "<span class='label'>#{item.type}</span>" else ''
            target = item.target || item.name || item
            lineInfo = if item.line then "<span class='line'>@#{item.line}</span>" else ''
            "<li>#{typeLabel} #{target} #{lineInfo}</li>"
          .join ''
          "<div><strong>#{type}</strong><ul>#{itemsHtml}</ul></div>"
        else ''
      
      importsHtml = renderImportExport(imports, '📥 Imports')
      exportsHtml = renderImportExport(exports, '📤 Exports')
      
      overview_html += """
        <div class="imports-exports-preview">
          <details>
            <summary>📦 Imports & Exports</summary>
            <div class="imports-exports-list">
              #{importsHtml}
              #{exportsHtml}
            </div>
          </details>
        </div>
      """
    
    # Add tag cloud and file cloud if available
    tag_cloud = off # file_info.tag_cloud || symbolic_data.tag_cloud
    file_cloud = off # file_info.file_cloud || symbolic_data.file_cloud
    
    if tag_cloud
      overview_html += """
        <div class="tag-cloud-preview">
          <details>
            <summary>🏷️ Tag Cloud</summary>
            <div class="tag-cloud">
              #{tag_cloud.map((tag) => "<span class='tag'>#{tag}</span>").join('')}
            </div>
          </details>
        </div>
      """
    
    if file_cloud 
      overview_html += """
        <div class="file-cloud-preview">
          <details>
            <summary>📁 File Cloud</summary>
            <div class="file-cloud">
              #{file_cloud.map((file) => "<span class='file-link'>#{file}</span>").join('')}
            </div>
          </details>
        </div>
      """
    
    # Add hermetic overview if available
    hermetic_hverview = file_info.hermetic_overview || symbolic_data.hermetic_overview
    if hermetic_hverview
      overview_html += @renderHermeticOverview(hermetic_hverview)
    
    overview_html += "</div>"
    
    return overview_html


  renderHierarchy: (data) ->
    console.log "renderHierarchy", data
    @hierarchyData = data
    @container.innerHTML = ''
    
    # Render header with basic file info
    header = document.createElement 'div'
    header.className = 'horologium-header'
    header.innerHTML = """
      <div class="file-info">
        <span class="language-badge">#{data.language || 'unknown'}</span>
        <span class="line-count">#{data.file_info?.lines || data.lines || 0} lines</span>
        <span class="file-size">#{data.file_info?.size || data.size || '0B'}</span>
      </div>
    """
    @container.appendChild header
    
    # Render structure section
    structureSection = document.createElement 'div'
    structureSection.className = 'horologium-structure'
    
    structureHeader = document.createElement 'div'
    structureHeader.className = 'structure-header'
    structureHeader.innerHTML = """
      <h3>🌳 Hierarchical Structure</h3>
      <span class="structure-summary">
        #{data.structural_summary?.containers || data.structure?.containers || 0} containers,
        #{data.structural_summary?.members || data.structure?.members || 0} members
      </span>
    """
    structureSection.appendChild structureHeader
    
    # Render hierarchy tree
    treeContainer = document.createElement 'div'
    treeContainer.className = 'hierarchy-tree'
    
    if data.hierarchy?.length
      @renderTree data.hierarchy, treeContainer, 0
    else
      treeContainer.innerHTML = '<div class="no-hierarchy">Flat structure (no hierarchy detected)</div>'
    
    structureSection.appendChild treeContainer
    @container.appendChild structureSection
    
    # Render imports/exports if available
    if data.imports?.length || data.exports?.length
      @renderImportsExports data
      
    # Render navigation hints
    if data.navigation?.length
      @renderNavigationHints data.navigation
  
  
  renderTree: (nodes, container, level = 0) ->
    nodes.forEach (node) =>
      item = document.createElement 'div'
      item.className = 'tree-item'
      item.style.marginLeft = "#{level * 20}px"
      
      # Determine icon based on node type
      icon = @getHierarchyIcon node.type
      
      # Check if node has children and if it should be expanded
      hasChildren = node.children?.length > 0
      isExpanded = hasChildren && @expandedNodes.has(node.name)
      
      # Handle Ruby class methods showing as "self" - extract actual method name
      display_name = if node.name == 'self' and node.type == 'class_method'
        @extractRubyMethodName(node, @hierarchyData) || 'class_method'
      else
        node.name
      
      item.innerHTML = """
        <div class="tree-node" data-node-id="#{node.name}">
          <span class="tree-icon">#{icon}</span>
          <span class="tree-name">#{display_name}</span>
          <span class="tree-line">@ line #{node.line}</span>
          #{if hasChildren then '<span class="tree-toggle">' + (if isExpanded then '▼' else '▶') + '</span>' else ''}
        </div>
      """
      
      container.appendChild item
      
      # Handle click to expand/collapse
      nodeElement = item.querySelector '.tree-node'
      nodeElement.addEventListener 'click', =>
        if hasChildren
          @toggleNode node.name
          @renderHierarchy @hierarchyData # Re-render
      
      # Render children if expanded
      if isExpanded && node.children?.length
        childrenContainer = document.createElement 'div'
        childrenContainer.className = 'tree-children'
        @renderTree node.children, childrenContainer, level + 1
        container.appendChild childrenContainer
          
  
  toggleNode: (nodeId) ->
    if @expandedNodes.has nodeId
      @expandedNodes.delete nodeId
    else
      @expandedNodes.add nodeId
  
  
  renderImportsExports: (data) ->
    section = document.createElement 'div'
    section.className = 'imports-exports'
    
    imports = data.imports || []
    exports = data.exports || []
    
    section.innerHTML = """
      <h3>📦 Imports & Exports</h3>
      <div class="imports">
        <h4>📥 Imports (#{imports.length})</h4>
        #{if imports.length then @renderList imports else '<div class="none">None</div>'}
      </div>
      <div class="exports">
        <h4>📤 Exports (#{exports.length})</h4>
        #{if exports.length then @renderList exports else '<div class="none">None</div>'}
      </div>
    """
    
    @container.appendChild(section)
  
  
  renderList: (items) ->
    """<ul>#{items.map((item) -> "<li>#{item}</li>").join ''}</ul>"""
  
  
  renderNavigationHints: (hints) ->
    section = document.createElement 'div'
    section.className = 'navigation-hints'
    
    navigationHints = hints || data.navigation_hints || []
    
    section.innerHTML = """
      <h3>🧭 Navigation Hints</h3>
      <div class="hints-grid">
        #{navigationHints.map((hint) => """
          <div class="hint-item">
            <span class="hint-line">L#{hint.line}</span>
            <span class="hint-text">#{hint.description || hint.text}</span>
          </div>
        """).join ''}
      </div>
    """
    
    @container.appendChild section


  # Hierarchy preview rendering for file overview status
  renderHierarchyPreview: (nodes, symbolic_data = {}, level = 0, file_info = {}) ->
    html = ''
    nodes.forEach (node) =>
      indent = '&nbsp;'.repeat(level * 2)
      icon = @getHierarchyIcon(node.type)
      
      # Handle Ruby class methods showing as "self" - extract actual method name from context
      display_name = if node.name == 'self' and node.type == 'class_method'
        # Try to extract method name from navigation hints or parent context
        @extractRubyMethodName(node, symbolic_data) || 'class_method'
      else
        node.name
      
      scope_indicator = if node.scope then " <small class='scope'>(#{node.scope})</small>" else ''
      
      # Create clickable link for hierarchical items
      filePath = file_info.path || symbolic_data.file_path || symbolic_data.path
      line = node.line
      
      # Generate TextMate link if pythia is available
      linkAttrs = ''
      if @pythia && filePath && line
        href = @pythia.createTextMateLink(filePath, line)
        linkAttrs = " href='#{href}' class='file-link'" if href
      
      html += """
        <div class="hierarchy-preview-item" style="margin-left: #{level * 10}px">
          <a#{linkAttrs}>
            #{indent}#{icon} #{display_name}#{scope_indicator} <small class="line-number">@#{node.line}</small>
          </a>
        </div>
      """
      
      # Render children with proper indentation (including local variables)
      # Handle both array children and object children with children property
      children = node.children || node.members || []
      if children?.length
        html += @renderHierarchyPreview(children, symbolic_data, level + 1, file_info)
    html


  getHierarchyIcon: (type) ->
    switch type
      when 'module', 'class' then '📦'
      when 'method', 'function', 'instance_method' then '🔧'
      when 'class_method', 'singleton_method' then '⚡️'
      when 'constant', 'variable' then '📌'
      when 'local_variable', 'local' then '📋'
      when 'instance_variable', 'ivar' then '🏷️'
      when 'class_variable', 'cvar' then '🔖'
      when 'global_variable', 'gvar' then '🌍'
      when 'import', 'require' then '📥'
      when 'export' then '📤'
      when 'private_method', 'private' then '🔒'
      when 'protected_method', 'protected' then '🛡️'
      when 'parameter', 'param' then '📝'
      when 'attribute', 'attr' then '🏷️'
      when 'block', 'lambda', 'proc' then '🔷'
      else '📄'


  # Utility method to format file size
  formatFileSize: (bytes) ->
    if bytes < 1024
      "#{bytes} B"
    else if bytes < 1024 * 1024
      "#{(bytes / 1024).toFixed(1)} KB"
    else
      "#{(bytes / (1024 * 1024)).toFixed(1)} MB"


  # Build hierarchy from structural summary data
  buildHierarchyFromStructuralData: (symbolic_data) ->
    hierarchy = []
    summary = symbolic_data.structural_summary
    
    if summary
      # Add classes
      if summary.classes > 0
        hierarchy.push 
          name: 'Classes',
          type: 'container',
          line: 1,
          children: Array(summary.classes).fill().map((_, i) ->
            name: "Class #{i + 1}", type: "class", line: 1 
          )
      
      # Add modules
      if summary.modules > 0
        hierarchy.push 
          name: "Modules",
          type: "container",
          line: 1,
          children: Array(summary.modules).fill().map((_, i) ->
            name: "Module #{i + 1}", type: "module", line: 1
          )
        
      # Add methods
      if summary.methods > 0
        hierarchy.push 
          name: "Methods",
          type: "container",
          line: 1,
          children: Array(summary.methods).fill().map((_, i) ->
            name: "method_#{i + 1}", type: "method", line: 1 
          )
        
      # Add constants
      if summary.constants > 0
        hierarchy.push 
          name: "Constants",
          type: "container",
          line: 1,
          children: Array(summary.constants).fill().map((_, i) ->
            name: "CONST_#{i + 1}", type: "constant", line: 1 
          )
        
      # Add variables
      if summary.variables > 0
        hierarchy.push 
          name: "Variables",
          type: "container",
          line: 1,
          children: Array(summary.variables).fill().map((_, i) ->
            name: "var_#{i + 1}", type: "variable", line: 1 
          )
        
    hierarchy


  # Extract Ruby method name from navigation hints for class methods showing as "self"
  extractRubyMethodName: (node, symbolic_data) ->
    return unless node.type == 'class_method' && node.name == 'self'
    
    # Look for navigation hints that reference this line
    navigationHints = symbolic_data.navigation_hints || symbolic_data.navigationHints || []
    
    # Find hints for this specific line
    lineHints = navigationHints.filter (hint) ->
      hint.line == node.line && hint.type == 'structure' && hint.target?.includes('class_method:')
    
    # Extract method name from target if available
    if lineHints.length > 0
      target = lineHints[0].target
      if target && target.includes(':')
        parts = target.split(':')
        if parts.length >= 2
          return parts[1]  # Return the method name part
    
    # Fallback: look for method name in parent context
    if node.parent_name
      return node.parent_name
    
    # Final fallback
    'class_method'
    
    

# Global class
window.Horologium = Horologium

# Auto-initialize when DOM is ready
document.addEventListener 'DOMContentLoaded', ->
  # Horologium is now a class that can be instantiated without container
  # and used directly by Pythia for status message rendering
  
  # Example: Trigger rendering when overview data is available
  window.renderFileOverview = (data) ->
    horologium = new Horologium()
    horologium.renderFileOverview(data)
      
      