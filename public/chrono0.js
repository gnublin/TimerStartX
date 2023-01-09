// MIT License
// Copyright (c) 2022 Gauthier FRANCOIS

let minutes0 = Number(document.getElementById('minutes-0').innerText);
let seconds0 = Number(document.getElementById('seconds-0').innerText);
let milliseconds0 = Number(document.getElementById('milliseconds-0').innerText);
let int0 = null;

if (milliseconds0 != 0)
    {
    if(int0!==null){
        clearInterval(int0);
    }
    int0 = setInterval(displayTimer0,10);
    }
function displayTimer0(){
milliseconds0+=10;
if(milliseconds0 >= 1000){
    milliseconds0 = 0;
    seconds0++;
    if(seconds0 == 60){
        seconds0 = 0;
        minutes0++;
        if(minutes0 == 60){
            minutes0 = 0;
            // hours++;
        }
    }
}
//  let h = hours < 10 ? "0" + hours : hours;
let m0 = minutes0 < 10 ? "0" + minutes0 : minutes0;
let s0 = seconds0 < 10 ? "0" + seconds0 : seconds0;
let ms0 = milliseconds0 < 10 ? "00" + milliseconds0 : milliseconds0 < 100 ? "0" + milliseconds0 : milliseconds0;

document.getElementById('minutes-0').innerHTML = ` ${m0} `;
document.getElementById('seconds-0').innerHTML = ` ${s0} `;
document.getElementById('milliseconds-0').innerHTML = ` ${ms0} `;
}