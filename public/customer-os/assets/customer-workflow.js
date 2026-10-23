/* KRIM Customer OS shared workflow bridge.
 * Shared navigation + session/membership verification for all Customer OS pages.
 * Sensitive operations remain on canonical, permission-checked application routes. */
(function(){
'use strict';
const BASE='/logistics-saas/';
const route=p=>(location.hostname.endsWith('github.io')?BASE:'/')+p.replace(/^\//,'');
const routes={
 home:'app/customer/index.html',
 book:'public/shipments/shipment-create.html',
 quotes:'public/customer/quote-request.html',
 quoteBoard:'public/shipper/quote-comparison.html',
 shipments:'public/customer-os/customer-services/shipment-list.html',
 tracking:'public/visibility/live-tracking-map.html',
 documents:'public/documents/document-list.html',
 payments:'public/shipper/payment-checkout.html',
 invoices:'public/customer-os/customer-services/invoices.html',
 claims:'public/customer-os/customer-services/claims.html',
 support:'public/support/ticket-desk.html',
 addresses:'public/customer-os/customer-services/address-book.html',
 profile:'public/customer-os/customer-services/company-profile.html',
 hub:'public/customer-os/index.html'
};
const navItems=[['Home','home'],['Book shipment','book'],['Quotes','quotes'],['Shipments','shipments'],['Tracking','tracking'],['Documents','documents'],['Payments','payments'],['Support','support'],['All services','hub']];
const contextActions=[
 {re:/shipment-create|booking-request|reorder|recurring-shipments/,title:'Continue booking',text:'Use the secured shipment booking form to create a real shipment record.',key:'book'},
 {re:/quote|pricing|rate-calculator|surcharge|currency-conversion|tax-estimation/,title:'Continue to live quotes',text:'Submit a real quote request or review quote records from the canonical KRIM workflow.',key:'quotes'},
 {re:/shipment-list|active-shipments|shipment-details|shipment-timeline|dispatch|pickup|milestone|route-planning|tracking|vessel|rail|air-cargo|road-tracking|eta|geofence|container-condition|temperature|deviation|delay-prediction/,title:'Open shipment operations',text:'View shipments or open live visibility tools in the canonical workflow.',key:'shipments'},
 {re:/invoice|payment|refund|settlement|treasury|cash-flow|transaction|credit-note|accounts-payable|accounts-receivable/,title:'Continue to billing',text:'Open the secured billing and payment workflow; never treat a pending payment as completed.',key:'payments'},
 {re:/claim|dispute|ticket|support|complaint|compensation|escalation/,title:'Continue to support',text:'Open the support/claims workflow to raise or review an issue.',key:'support'},
 {re:/document|certificate|licence|license|consignment|signature|epod|pod-/,title:'Open document records',text:'Use the document workflow to view or submit supported shipment evidence.',key:'documents'},
 {re:/address|location|company-profile|team-members|onboarding|verification|cargo-profile|shipping-preference|saved-route/,title:'Manage customer setup',text:'Return to your customer workspace and organization setup tools.',key:'home'}
];
function status(message,kind){let box=document.getElementById('krim-workflow-status');if(!box){box=document.createElement('div');box.id='krim-workflow-status';(document.querySelector('main')||document.body).prepend(box)}box.textContent=message;box.style.cssText='margin:12px auto;max-width:1100px;padding:10px 14px;border-radius:10px;background:'+(kind==='ok'?'#e8f8f0':kind==='error'?'#fff0ef':'#eaf2ff')+';color:'+(kind==='ok'?'#086548':kind==='error'?'#a12820':'#173b72')+';font:12px/1.5 system-ui'};
function applyDesignSystem(){
 const slug=location.pathname.split('/').pop().replace(/\.html$/,'').toLowerCase();
 const module=/invoice|payment|refund|settlement|credit-note|finance/.test(slug)?'finance':/quote|pricing|rate-calculator|contract-rate/.test(slug)?'commercial':/pod|delivery|tracking|shipment|booking|recurring|reorder|return/.test(slug)?'operations':/claim|dispute|support|ticket/.test(slug)?'service':/profile|address|team|onboarding|verification|location|preference/.test(slug)?'account':'core';
 document.documentElement.dataset.krimModule=module;
 if(document.body)document.body.dataset.krimModule=module;
 if(!document.getElementById('krim-customer-design-system')){
  const link=document.createElement('link');link.id='krim-customer-design-system';link.rel='stylesheet';link.href=route('public/customer-os/assets/customer-os-design.css');document.head.appendChild(link);
 }
}
function navigation(){
 if(document.getElementById('krim-global-customer-nav'))return;
 const nav=document.createElement('nav');nav.id='krim-global-customer-nav';nav.setAttribute('aria-label','KRIM customer workflow');
 nav.style.cssText='display:flex;gap:8px;flex-wrap:wrap;align-items:center;padding:12px max(16px,calc((100% - 1100px)/2));background:#fff;border-bottom:1px solid #dfe7f2;font:12px system-ui';
 nav.innerHTML=navItems.map(([label,key])=>'<a style="padding:8px 11px;border-radius:8px;background:#f0f5ff;color:#174ea6;text-decoration:none;font-weight:750" href="'+route(routes[key])+'">'+label+'</a>').join('');
 const header=document.querySelector('header');if(header)header.insertAdjacentElement('afterend',nav);else document.body.prepend(nav);
}
function workflowPanel(){
 if(document.getElementById('krim-next-step'))return;
 const slug=location.pathname.split('/').pop().replace(/\.html$/,'');
 const found=contextActions.find(x=>x.re.test(slug));const action=found||{title:'Continue customer journey',text:'Use the shared customer workspace to continue to bookings, quotes, shipment visibility, documents, billing and support.',key:'home'};
 const box=document.createElement('section');box.id='krim-next-step';box.style.cssText='max-width:1100px;margin:14px auto;padding:16px;border:1px solid #dbe5f2;border-radius:14px;background:linear-gradient(120deg,#fff,#f0f6ff);font:13px/1.5 system-ui;color:#172943';
 box.innerHTML='<strong style="font-size:15px">'+action.title+'</strong><p style="margin:6px 0 12px;color:#5b6c83">'+action.text+'</p><div style="display:flex;gap:8px;flex-wrap:wrap"><a style="padding:9px 12px;border-radius:9px;background:#1769ff;color:white;text-decoration:none;font-weight:800" href="'+route(routes[action.key])+'">Continue →</a><a style="padding:9px 12px;border:1px solid #cfdaeb;border-radius:9px;background:white;color:#174ea6;text-decoration:none;font-weight:800" href="'+route(routes.hub)+'">Browse all customer pages</a></div>';
 const main=document.querySelector('main');if(main)main.appendChild(box);else document.body.appendChild(box);
}
async function init(){
 applyDesignSystem();navigation();workflowPanel();
 const client=window.KRIM_SUPABASE||window.supabaseClient;
 if(!client){status('Navigation is connected. This page did not load the Supabase client, so protected records and actions are not enabled here.','error');return}
 try{
  const {data,error}=await client.auth.getSession();if(error)throw error;
  if(!data||!data.session){status('Public workflow view. Sign in to access account-specific records and protected actions.');return}
  const user=data.session.user;
  const result=await client.from('krim_organization_members').select('organization_id,role,status').eq('user_id',user.id).eq('status','active');
  if(result.error)throw result.error;
  if(!result.data||!result.data.length){status('Signed in as '+(user.email||'KRIM user')+', but no active KRIM organization membership was found. Contact your organization administrator.','error');return}
  const ids=[...new Set(result.data.map(x=>x.organization_id).filter(Boolean))];
  window.KRIM_CUSTOMER_WORKFLOW={userId:user.id,email:user.email,organizationIds:ids,memberships:result.data,client};
  const badge=document.createElement('span');badge.textContent='Verified session · '+(user.email||'KRIM account');badge.style.cssText='padding:8px;color:#087e5b;font:700 12px system-ui';
  const nav=document.getElementById('krim-global-customer-nav');if(nav)nav.appendChild(badge);
  status('Signed in and active organization membership verified. This navigation opens canonical workflow routes; each data change must still be confirmed by its backend response and database permissions.','ok');
 }catch(e){status('Could not verify account access with KRIM. Refresh or sign in again. Details: '+(e&&e.message?e.message:'access check failed'),'error')}
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
})();