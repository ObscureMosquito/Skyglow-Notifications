document.addEventListener("DOMContentLoaded", function(event) {
    var collapsible = document.getElementsByClassName("collapsible");
    for (var i = 0; i < collapsible.length; i++) {
        collapsible[i].addEventListener("click", function() {
            this.classList.toggle("active");
            var content = this.nextElementSibling;
            if (content.style.maxHeight){
                content.style.maxHeight = null;
            } else {
                content.style.maxHeight = content.scrollHeight + "px";
            } 
        });
    }
});