const Http = new XMLHttpRequest();

function call_http(ts_state) {
  url = '/competitor_';
  url = url + ts_state;
  tdate = new Date().getTime();
  Http.open("POST", url, true);
  Http.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
  Http.onreadystatechange = (e) => {
    console.log(Http.responseText)
  }
  Http.send(`ts=${tdate}`);

}
