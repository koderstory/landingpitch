document.addEventListener("DOMContentLoaded", function () {

    // reading time bar
    console.log("DOM fully loaded and parsed");
    let processScroll = () => {
        let docElem = document.documentElement,
            docBody = document.body,
            scrollTop = docElem['scrollTop'] || docBody['scrollTop'],
            scrollBottom = (docElem['scrollHeight'] || docBody['scrollHeight']) - window.innerHeight,
            scrollPercent = scrollTop / scrollBottom * 100 + '%';

        // console.log(scrollTop + ' / ' + scrollBottom + ' / ' + scrollPercent);

        document.getElementById("progress-bar").style.setProperty("--scrollAmount", scrollPercent);
    }
    document.addEventListener('scroll', processScroll);

    function readingTime() {
        const text = document.getElementById("article").innerText;
        const wpm = 225;
        const words = text.trim().split(/\s+/).length;
        const time = Math.ceil(words / wpm);
        document.getElementById("time").innerText = time;
        console.log("time: " + time);
    }

    readingTime();


});
