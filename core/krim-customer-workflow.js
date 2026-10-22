/* KRIM Customer Workflow Navigation — navigation only; does not imply backend readiness */
(function(){
 if(window.__KRIM_CUSTOMER_FLOW_NAV__) return; window.__KRIM_CUSTOMER_FLOW_NAV__=true;
 var root='/logistics-saas/';
 if(location.pathname.indexOf('/logistics-saas/')!==0) root='/';
 var links=[
  ['Customer workspace',root+'app/customer/index.html'],
  ['Workflow directory',root+'public/customer/workflow-hub.html'],
  ['New shipment',root+'public/shipments/shipment-create.html'],
  ['Quotes',root+'public/quotes/quote-list.html'],
  ['Track shipment',root+'public/tracking.html'],
  ['Documents',root+'public/app/document-vault.html'],
  ['Invoices & payments',root+'public/finance/finance-dashboard.html'],
  ['Support & claims',root+'public/support/help-centre.html']
 ];
 var bar=document.createElement('nav');bar.className='krim-flowbar';bar.setAttribute('aria-label','KRIM customer workflow navigation');
 var inner=document.createElement('div');inner.className='kf-inner';
 var brand=document.createElement('a');brand.className='kf-brand';brand.href=root+'index.html';brand.innerHTML='K<span>R</span>IM <span>GLOBAL LOGISTICS</span>';brand.setAttribute('aria-label','KRIM Global Logistics homepage');inner.appendChild(brand);
 var nav=document.createElement('div');nav.className='kf-links';
 links.forEach(function(item){var a=document.createElement('a');a.href=item[1];a.textContent=item[0];nav.appendChild(a)});
 var status=document.createElement('span');status.className='kf-status';status.textContent='Shared customer navigation · workflow status depends on each service';nav.appendChild(status);
 inner.appendChild(nav);bar.appendChild(inner);
 function mount(){if(document.body&&!document.querySelector('.krim-flowbar'))document.body.insertBefore(bar,document.body.firstChild)}
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mount,{once:true});else mount();
})();