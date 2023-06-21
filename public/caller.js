// MIT License
// Copyright (c) 2022 Gauthier FRANCOIS

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

function stop_last(ts_state, last) {
  url = '/competitor_';
  url = url + ts_state;
  tdate = new Date().getTime();
  Http.open("POST", url, true);
  Http.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
  Http.onreadystatechange = (e) => {
    console.log(Http.responseText)
  }
  Http.send(`ts=${tdate}&last=${last}`);
}

function call_obstacle(obtype, obstate, run_id, competior_id) {
  url = '/obstacle';
  Http.open("POST", url, true);
  Http.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
  Http.onreadystatechange = (e) => {
    console.log(Http.responseText)
  }
  Http.send(`type=${obtype}&state=${obstate}&run_id=${run_id}&competitor_id=${competior_id}`);
}
