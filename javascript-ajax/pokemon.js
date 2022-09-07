function getPokemonData(name) {
  var xhr = new XMLHttpRequest(); // to create new object
  xhr.open('GET', 'https://pokeapi.co/api/v2/pokemon/' + name); // to set request method and URL
  xhr.responseType = 'json'; // to parse JSON response body into JS objects
  xhr.addEventListener('load', function () { // once reponse is loaded, execute function
    console.log(xhr.status); // read status code of response message
    console.log(xhr.response); // get body of http response once it has been converted from JSON string --> JS objects
  });
  xhr.send(); // send request to server at URL specified in xhr.open()
}

getPokemonData('cubone');
