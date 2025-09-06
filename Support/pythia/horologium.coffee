###
Horologium - Hierarchical File Overview Rendering
Enhances file overview display with proper hierarchical visualization
###

class Horologium
  constructor: ->
    @hierarchyData = null
    @expandedNodes = new Set
    @pythia = window.pythia


  renderFileOverview: (fileData) ->
    console.log "renderFileOverview", fileData
    
    # Data structure: data.result.data.data contains the actual file info
    # Handle nested structure: data.result.data.data.file_info and data.result.data.data.symbolic_overview
    resultData = fileData.data || fileData
    fileInfo = resultData.file_info || resultData.data?.file_info || {}
    symbolicData = resultData.symbolic_overview || resultData.data?.symbolic_overview || resultData
    { imports, exports } = symbolicData
    
    # Handle the case where data is nested under result.data
    if resultData.data
      fileInfo = resultData.data.file_info || fileInfo
      symbolicData = resultData.data.symbolic_overview || symbolicData
    
    # Handle deeply nested data structure: data.result.data.data.file_info
    if resultData.result?.data?.file_info
      fileInfo = resultData.result.data.file_info
      symbolicData = resultData.result.data.symbolic_overview || symbolicData
    
    language = symbolicData.language || symbolicData.structural_summary?.language || 'unknown'
    lines = fileInfo.lines || symbolicData.lines || 0
    size = if fileInfo.size then @formatFileSize(fileInfo.size) else '0B'
    containers = symbolicData.structural_summary?.containers || symbolicData.structure?.containers || 0
    members = symbolicData.structural_summary?.members || symbolicData.structure?.members || 0
    
    # Get comprehensive statistics from structure data
    structure = symbolicData.structure || symbolicData.structural_summary || {}
    import_count = structure.import_count || imports.length
    export_count = structure.export_count || exports.length
    symbol_count = structure.symbol_count || (symbolicData.symbols?.length || 0)
    variables = structure.variables || 0
    
    overviewHtml = """
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
    hierarchy = symbolicData.hierarchy || fileInfo.hierarchy
    
    # If hierarchy is empty but we have structural data, try to build it
    if (!hierarchy || hierarchy.length == 0) && symbolicData.structural_summary
      hierarchy = @buildHierarchyFromStructuralData(symbolicData)
    
    if hierarchy?.length
      overviewHtml += """
        <div class="hierarchy-preview">
          <details open>
            <summary>🌳 Hierarchical Structure</summary>
            <div class="hierarchy-tree-preview">
              #{@renderHierarchyPreview(hierarchy, symbolicData)}
            </div>
          </details>
        </div>
      """
    
    # Add imports/exports if available
    imports = symbolicData.imports || fileInfo.imports || []
    exports = symbolicData.exports || fileInfo.exports || []
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
      
      overviewHtml += """
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
    
    # Add notes if available
    notes = fileData.notes_metadata || symbolicData.relevant_notes || fileInfo.notes_preview || []
    if notes?.length
      overviewHtml += """
        <div class="notes-preview">
          <details>
            <summary>📝 Related Notes (#{notes.length})</summary>
            <div class="notes-list">
              #{notes.map((note) =>
                "<div class='note-item'><strong>#{note.title || 'Note'}:</strong> #{note.content?.substring(0, 100) || note.excerpt || 'No content'}...</div>"
              ).join('')}
            </div>
          </details>
        </div>
      """
    
    overviewHtml += "</div>"
    
    return overviewHtml


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
      displayName = if node.name == 'self' and node.type == 'class_method'
        @extractRubyMethodName(node, @hierarchyData) || 'class_method'
      else
        node.name
      
      item.innerHTML = """
        <div class="tree-node" data-node-id="#{node.name}">
          <span class="tree-icon">#{icon}</span>
          <span class="tree-name">#{displayName}</span>
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
  renderHierarchyPreview: (nodes, symbolicData = {}, level = 0) ->
    html = ''
    nodes.forEach (node) =>
      indent = '&nbsp;'.repeat(level * 2)
      icon = @getHierarchyIcon(node.type)
      
      # Handle Ruby class methods showing as "self" - extract actual method name from context
      displayName = if node.name == 'self' and node.type == 'class_method'
        # Try to extract method name from navigation hints or parent context
        @extractRubyMethodName(node, symbolicData) || 'class_method'
      else
        node.name
      
      scopeIndicator = if node.scope then " <small class='scope'>(#{node.scope})</small>" else ''
      
      # Create clickable link for hierarchical items
      filePath = symbolicData.file_path || symbolicData.path
      line = node.line
      
      # Generate TextMate link if pythia is available
      linkAttrs = ''
      if @pythia && filePath && line
        href = @pythia.createTextMateLink(filePath, line)
        linkAttrs = " href='#{href}' class='file-link'" if href
      
      html += """
        <div class="hierarchy-preview-item" style="margin-left: #{level * 10}px">
          <a#{linkAttrs}>
            #{indent}#{icon} #{displayName}#{scopeIndicator} <small class="line-number">@#{node.line}</small>
          </a>
        </div>
      """
      
      # Render children with proper indentation (including local variables)
      # Handle both array children and object children with children property
      children = node.children || node.members || []
      if children?.length
        html += @renderHierarchyPreview(children, symbolicData, level + 1)
    html

  getHierarchyIcon: (type) ->
    switch type
      when 'module', 'class' then '📦'
      when 'method', 'function', 'instance_method' then '🔧'
      when 'class_method', 'singleton_method' then '⚡'
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
  buildHierarchyFromStructuralData: (symbolicData) ->
    hierarchy = []
    summary = symbolicData.structural_summary
    
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
  extractRubyMethodName: (node, symbolicData) ->
    return unless node.type == 'class_method' && node.name == 'self'
    
    # Look for navigation hints that reference this line
    navigationHints = symbolicData.navigation_hints || symbolicData.navigationHints || []
    
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
      