// MIT License
// Copyright (c) 2022 Gauthier FRANCOIS

const evtSource = new EventSource("//localhost:9292/events");

evtSource.onmessage = (e) => {
    console.log(`message: ${e.data}`);
    location.reload();
}
