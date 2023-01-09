const Http = new XMLHttpRequest();

function call_http(ts_state) {
  url = 'http://localhost:9292/push?';
  url = url + ts_state;
  url = url + '=';
  tdate = new Date().getTime()
  url = url + tdate
  Http.open("GET", url);
  Http.send();
  Http.onreadystatechange = (e) => {
    console.log(Http.responseText)
  }
}
