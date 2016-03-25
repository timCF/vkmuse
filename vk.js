console.log("whoo, execute begin!!!");
var closemodal = function(){
    var el = document.getElementsByClassName("box_x_button")[0];
    console.log(el);
	if(el){
        var click = new MouseEvent("click", { "view": window, "bubbles": true, "cancelable": false });
        el.dispatchEvent(click);
    };
};
setInterval(closemodal, 5000);
console.log("whoo, execute autoclick!!!");
