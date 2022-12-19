// MIT License
// Copyright (c) 2022 Gauthier FRANCOIS

// let [milliseconds,seconds,minutes,hours] = [0,0,0,0];
let hours = Number(document.getElementById('hours').innerText);
let minutes = Number(document.getElementById('minutes').innerText);
let seconds = Number(document.getElementById('seconds').innerText);
let milliseconds = Number(document.getElementById('milliseconds').innerText);
let timerRef = document.querySelector('.timerDisplay');
let int = null;
const evtSource = new EventSource("//localhost:9292/events");

evtSource.onmessage = (e) => {
    console.log(`message: ${e.data}`);
    location.reload();
}

document.getElementById('startTimer').addEventListener('click', ()=>{
    if(int!==null){
        clearInterval(int);
    }
    int = setInterval(displayTimer,10);
});

document.getElementById('pauseTimer').addEventListener('click', ()=>{
    clearInterval(int);
});

document.getElementById('resetTimer').addEventListener('click', ()=>{
    clearInterval(int);
    [milliseconds,seconds,minutes,hours] = [0,0,0,0];
    timerRef.innerHTML = '00 : 00 : 00 : 000 ';
});

function displayTimer(){
    milliseconds+=10;
    if(milliseconds >= 1000){
        milliseconds = 0;
        seconds++;
        if(seconds == 60){
            seconds = 0;
            minutes++;
            if(minutes == 60){
                minutes = 0;
                hours++;
            }
        }
    }
 let h = hours < 10 ? "0" + hours : hours;
 let m = minutes < 10 ? "0" + minutes : minutes;
 let s = seconds < 10 ? "0" + seconds : seconds;
 let ms = milliseconds < 10 ? "00" + milliseconds : milliseconds < 100 ? "0" + milliseconds : milliseconds;

document.getElementById('hours').innerHTML = ` ${h} `;
document.getElementById('minutes').innerHTML = ` ${m} `;
document.getElementById('seconds').innerHTML = ` ${s} `;
document.getElementById('milliseconds').innerHTML = ` ${ms} `;
}
