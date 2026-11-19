/* KRIM official social destinations and accessible icon navigation. */
(function(){
  "use strict";
  var icons={
    Facebook:'<path d="M13.5 21v-8h2.7l.4-3.1h-3.1V8c0-.9.3-1.5 1.6-1.5h1.7V3.7c-.3 0-1.3-.1-2.5-.1-2.5 0-4.2 1.5-4.2 4.3v2H7.3V13h2.8v8z"/>',
    Instagram:'<rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.7" r=".8" fill="currentColor" stroke="none"/>',
    LinkedIn:'<path d="M5 8.5H2V21h3zM3.5 2a1.8 1.8 0 1 0 0 3.6 1.8 1.8 0 0 0 0-3.6M21 13.2c0-3.7-2-5.4-4.6-5.4a4 4 0 0 0-3.6 2V8.5h-3V21h3v-6.2c0-1.6.3-3.2 2.3-3.2s2 1.9 2 3.3V21h3z"/>',
    YouTube:'<path d="M23 7.2a3 3 0 0 0-2.1-2.1C19 4.6 12 4.6 12 4.6s-7 0-8.9.5A3 3 0 0 0 1 7.2 31 31 0 0 0 .5 12a31 31 0 0 0 .5 4.8 3 3 0 0 0 2.1 2.1c1.9.5 8.9.5 8.9.5s7 0 8.9-.5a3 3 0 0 0 2.1-2.1 31 31 0 0 0 .5-4.8 31 31 0 0 0-.5-4.8M9.8 15.5v-7l6 3.5z"/>',
    WhatsApp:'<path d="M20.5 11.8a8.5 8.5 0 0 1-12.6 7.4L3 20.5l1.3-4.7a8.5 8.5 0 1 1 16.2-4z"/><path d="M8.2 7.8c-.3.4-.7 1-.7 1.8 0 1 .7 2.1 1.5 3 .8 1 2.3 2.5 4.6 3.4 1.7.7 2.3.6 2.7.5.5-.1 1.4-.6 1.6-1.2.2-.6.2-1.1.1-1.2-.1-.1-.3-.2-.7-.4l-1.7-.8c-.2-.1-.4-.1-.6.2l-.8 1c-.2.2-.3.2-.6.1a6.8 6.8 0 0 1-2-1.2 7.4 7.4 0 0 1-1.4-1.7c-.1-.2 0-.4.1-.5l.5-.6c.2-.2.2-.4.3-.6 0-.2 0-.4-.1-.6l-.8-1.9c-.2-.4-.4-.4-.6-.4z"/>'
  };
  var links=[
    {label:"Facebook",href:"https://www.facebook.com/1405128699351990"},
    {label:"Instagram",href:"https://www.instagram.com/krimlogistics/"},
    {label:"LinkedIn",href:"https://www.linkedin.com/company/krim-logistics/"},
    {label:"YouTube",href:"https://www.youtube.com/channel/UCXlIzrjD8Ei7eMU97YxXOAg"},
    {label:"WhatsApp",href:"https://wa.me/916204624596"}
  ];
  document.querySelectorAll("[data-krim-social]").forEach(function(container){
    var nav=document.createElement("nav");
    nav.className="krim-social"+(container.classList.contains("krim-social-footer")?" krim-social-footer":"");
    nav.setAttribute("aria-label","KRIM Logistics social channels");
    links.forEach(function(item){
      var a=document.createElement("a");
      a.href=item.href;a.target="_blank";a.rel="noopener noreferrer";
      a.setAttribute("aria-label","KRIM Logistics on "+item.label+" (opens in a new tab)");
      a.title=item.label;
      var icon=document.createElement("span");
      icon.className="social-icon";icon.setAttribute("aria-hidden","true");
      icon.innerHTML='<svg viewBox="0 0 24 24" focusable="false" aria-hidden="true">'+icons[item.label]+'</svg>';
      var label=document.createElement("span");label.className="social-label";label.textContent=item.label;
      a.append(icon,label);nav.appendChild(a);
    });
    container.appendChild(nav);
  });
})();