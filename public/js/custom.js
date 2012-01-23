function getParameterByName(name) {
  var match = RegExp('[?&]' + name + '=([^&]*)').exec(window.location.search);
  return match && decodeURIComponent(match[1].replace(/\+/g, ' '));
}

function keysOf(hash) {
  var result = []
  for (var key in hash) {
    if (hash.hasOwnProperty(key)) {
      result.push(key)
    }
  }
  console.log(result)
  return result
}
