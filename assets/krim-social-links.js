/* Official KRIM social destinations. Keep this single source of truth. */
(function(){
  "use strict";
  var links=[
    {label:"Facebook",href:"https://www.facebook.com/1405128699351990",mark:"f"},
    {label:"Instagram",href:"https://www.instagram.com/krimlogistics/",mark:"◎"},
    {label:"LinkedIn",href:"https://www.linkedin.com/in/krim-logistics-0b609b448",mark:"in"},
    {label:"YouTube",href:"https://www.youtube.com/channel/UCXlIzrjD8Ei7eMU97YxXOAg",mark:"▶"},
    {label:"WhatsApp",href:"https://wa.me/916204624596",mark:"✆"}
  ];
  document.querySelectorAll("[data-krim-social]").forEach(function(container){
    var nav=document.createElement("nav");
    nav.className="krim-social"+(container.classList.contains("krim-social-footer")?" krim-social-footer":"");
    nav.setAttribute("aria-label","KRIM Logistics social media");
    links.forEach(function(item){
      var a=document.createElement("a");
      a.href=item.href;
      a.target="_blank";
      a.rel="noopener noreferrer";
      a.setAttribute("aria-label","KRIM Logistics on "+item.label+" (opens in a new tab)");
      var mark=document.createElement("span");
      mark.className="social-mark";
      mark.setAttribute("aria-hidden","true");
      mark.textContent=item.mark;
      var label=document.createElement("span");
      label.textContent=item.label;
      a.append(mark,label);
      nav.appendChild(a);
    });
    container.appendChild(nav);
  });
})();
