// Pure helper functions for Kasm Workspaces calculations and formatting

function formatMemory(mb) {
  var n = Number(mb) || 0
  if (n <= 0) return ""
  if (n >= 1024) return (n / 1024).toFixed(1).replace(/\.0$/, "") + " GB RAM"
  return n + " MB RAM"
}

function formatCores(c) {
  var n = Number(c) || 0
  if (n <= 0) return ""
  return n + " CPU" + (n > 1 ? "s" : "")
}

function filterWorkspaces(images, filterQuery, activeCategory) {
  if (!images || !Array.isArray(images)) return []
  var query = String(filterQuery || "").trim().toLowerCase()
  var cat = String(activeCategory || "all").toLowerCase()

  var results = []
  for (var i = 0; i < images.length; i++) {
    var img = images[i]
    if (!img) continue
    if (cat !== "all" && String(img.category || "").toLowerCase() !== cat) continue

    if (query !== "") {
      var name = String(img.name || "").toLowerCase()
      var desc = String(img.description || "").toLowerCase()
      var cName = String(img.category || "").toLowerCase()
      if (name.indexOf(query) === -1 && desc.indexOf(query) === -1 && cName.indexOf(query) === -1) {
        continue
      }
    }
    results.push(img)
  }
  return results
}

function extractCategories(images) {
  var map = { "All": true }
  var list = ["All"]
  for (var i = 0; i < (images || []).length; i++) {
    var c = images[i] && images[i].category
    if (c && !map[c]) {
      map[c] = true
      list.push(c)
    }
  }
  return list
}
