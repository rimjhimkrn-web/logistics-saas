/* KRIM official social destinations and accurate, accessible brand icons. */
(function(){
  "use strict";
  var icons={
    Facebook:'<path class="brand-fill" d="M13.4 21v-8h2.7l.4-3.1h-3.1V8c0-.9.3-1.5 1.6-1.5h1.7V3.7c-.3 0-1.3-.1-2.5-.1-2.5 0-4.2 1.5-4.2 4.3v2H7.3V13h2.8v8z"/>',
    Instagram:'<rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.5" cy="6.7" r="1" class="brand-fill"/>',
    LinkedIn:'<path class="brand-fill" d="M5 8.5H2V21h3zM3.5 2a1.8 1.8 0 1 0 0 3.6 1.8 1.8 0 0 0 0-3.6M21 13.2c0-3.7-2-5.4-4.6-5.4a4 4 0 0 0-3.6 2V8.5h-3V21h3v-6.2c0-1.6.3-3.2 2.3-3.2s2 1.9 2 3.3V21h3z"/>',
    YouTube:'<path class="brand-fill" d="M23 7.2a3 3 0 0 0-2.1-2.1C19 4.6 12 4.6 12 4.6s-7 0-8.9.5A3 3 0 0 0 1 7.2 31 31 0 0 0 .5 12a31 31 0 0 0 .5 4.8 3 3 0 0 0 2.1 2.1c1.9.5 8.9.5 8.9.5s7 0 8.9-.5a3 3 0 0 0 2.1-2.1 31 31 0 0 0 .5-4.8 31 31 0 0 0-.5-4.8M9.8 15.5v-7l6 3.5z"/>',
    WhatsApp:'<path d="M20.2 11.7a8.2 8.2 0 0 1-12.1 7.2L3 20l1.2-4.9a8.2 8.2 0 1 1 16-3.4z"/><path class="brand-fill" d="M9 7.7c-.3 0-.6.1-.8.4-.3.3-.9.9-.9 2.1s.9 2.4 1 2.6c.1.2 1.8 2.9 4.4 3.9 2.2.9 2.6.7 3.1.7.5-.1 1.6-.7 1.8-1.3.2-.6.2-1.1.1-1.3-.1-.1-.3-.2-.7-.4l-1.9-.9c-.2-.1-.4-.1-.6.2l-.9 1.1c-.2.2-.3.2-.6.1-.3-.1-1.2-.4-2.2-1.3-.8-.7-1.3-1.6-1.5-1.9-.2-.3 0-.4.1-.6l.5-.6c.2-.2.2-.3.3-.5.1-.2 0-.4 0-.5l-.9-2.1c-.2-.5-.5-.5-.7-.5z"/>'
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