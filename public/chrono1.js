// MIT License
// Copyright (c) 2022 Gauthier FRANCOIS

// let hours = 0;
let minutes1 = Number(document.getElementById('minutes-1').innerText);
let seconds1 = Number(document.getElementById('seconds-1').innerText);
let milliseconds1 = Number(document.getElementById('milliseconds-1').innerText);
let int1 = null;

if (milliseconds1 != 0)
    {
    if(int1!==null){
        clearInterval(int1);
    }
    int = setInterval(displayTimer1,10);
    }
function displayTimer1(){
milliseconds1+=10;
if(milliseconds1 >= 1000){
    milliseconds1 = 0;
    seconds1++;
    if(seconds1 == 60){
        seconds1 = 0;
        minutes1++;
        if(minutes1 == 60){
            minutes1 = 0;
            // hours++;
        }
    }
}

let m1 = minutes1 < 10 ? "0" + minutes1 : minutes1;
let s1 = seconds1 < 10 ? "0" + seconds1 : seconds1;
let ms1 = milliseconds1 < 10 ? "00" + milliseconds1 : milliseconds1 < 100 ? "0" + milliseconds1 : milliseconds1;

document.getElementById('minutes-1').innerHTML = ` ${m1} `;
document.getElementById('seconds-1').innerHTML = ` ${s1} `;
document.getElementById('milliseconds-1').innerHTML = ` ${ms1} `;
}