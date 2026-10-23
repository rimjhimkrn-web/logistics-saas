(function(){
'use strict';
const client=window.KRIM_SUPABASE||window.supabaseClient,$=id=>document.getElementById(id);
const view=document.body.dataset.shipmentView||'details';
const params=new URLSearchParams(location.search),shipmentId=Number(params.get('shipment_id'));
let orgIds=[],shipment=null,currentUserId=null;let userTimezone=Intl.DateTimeFormat().resolvedOptions().timeZone||'UTC';let timezoneSource='device default';
function path(p){return window.krimPath?window.krimPath(p):p}
function say(text,kind){const el=$('feedback');el.textContent=text;el.className='notice'+(kind?' '+kind:'')}
function node(tag,cls,text){const e=document.createElement(tag);if(cls)e.className=cls;if(text!==undefined)e.textContent=text;return e}
function date(v){if(!v)return 'Not recorded';const d=new Date(v);if(Number.isNaN(d.getTime()))return 'Not recorded';try{return d.toLocaleString(undefined,{dateStyle:'medium',timeStyle:'short',timeZone:userTimezone})+' ('+userTimezone+')'}catch{return d.toLocaleString()+' (device time zone)'}}
async function loadUserPreferences(){try{const {data,error}=await client.from('krim_user_app_preferences').select('preferences').eq('user_id',currentUserId||'').maybeSingle();if(error)return;const saved=data?.preferences?.customer_localization?.timezone;if(saved){try{new Intl.DateTimeFormat('en',{timeZone:saved}).format();userTimezone=saved;timezoneSource='saved account preference'}catch{}}}catch{}} 
function trackingFreshness(v){if(!v)return 'No verified tracking event recorded; current location is unavailable.';const t=new Date(v).getTime();if(!Number.isFinite(t))return 'Event timestamp is invalid; freshness cannot be assessed.';const age=Date.now()-t;if(age>24*60*60*1000)return 'Latest recorded event is over 24 hours old; the current position may be stale. This is a freshness warning, not a delivery SLA.';if(age< -5*60*1000)return 'Recorded event time is in the future; freshness requires review.';return 'Latest recorded event is within 24 hours. This is recorded-event visibility, not live GPS.'}
function field(label,value){const b=node('div','field');b.append(node('div','label',label),node('div','value',value||'Not recorded'));$('fields').appendChild(b)}
function place(label){return label||'Location not recorded'}
async function access(){
 if(!client)throw new Error('KRIM configuration did not load. Refresh and retry.');
 const {data:auth,error:ae}=await client.auth.getSession();if(ae)throw ae;
 if(!auth?.session){location.replace(path('auth/login.html')+'?role=customer&next='+encodeURIComponent(location.pathname+location.search));return false}currentUserId=auth.session.user.id;
 const {data:members,error:me}=await client.from('krim_organization_members').select('organization_id').eq('user_id',auth.session.user.id).eq('status','active');if(me)throw me;
 const ids=[...new Set((members||[]).map(m=>Number(m.organization_id)).filter(Number.isSafeInteger))];if(!ids.length)throw new Error('No active KRIM organization membership was found.');
 const {data:orgs,error:oe}=await client.from('krim_organizations').select('id,organization_type,status').in('id',ids).eq('status','active');if(oe)throw oe;
 orgIds=(orgs||[]).filter(o=>['customer','shipper','enterprise'].includes(String(o.organization_type||'').toLowerCase())).map(o=>Number(o.id));if(!orgIds.length)throw new Error('This account has no active customer, shipper or enterprise organization.');
 return true
}
async function loadShipment(){
 if(!Number.isSafeInteger(shipmentId)||shipmentId<=0){say('A valid shipment_id is required. Open a shipment from your authorized shipment register.','warn');$('title').textContent='Shipment reference required';return false}
 const {data:s,error}=await client.from('krim_shipments').select('id,shipment_number,customer_organization_id,origin_location_id,destination_location_id,goods_description,total_weight_kg,status,created_at,updated_at,estimated_delivery_at,actual_delivery_at,last_known_location_id,requested_transport_mode,origin_place_label,destination_place_label,requested_route_type').eq('id',shipmentId).in('customer_organization_id',orgIds).maybeSingle();if(error)throw error;
 if(!s){say('Shipment not found inside your authorized customer organizations. No outside-organization record was revealed.','error');$('title').textContent='Shipment not available';return false}
 shipment=s;
 const ids=[...new Set([Number(s.origin_location_id),Number(s.destination_location_id),Number(s.last_known_location_id)].filter(Number.isSafeInteger))];
 const {data:locations,error:le}=ids.length?await client.from('krim_locations').select('id,city,state_region,region,location_code,latitude,longitude').in('id',ids):{data:[],error:null};if(le)throw le;
 const map=new Map((locations||[]).map(l=>[Number(l.id),l]));
 const label=id=>{const l=map.get(Number(id));return l?[l.city,l.state_region||l.region,l.location_code].filter(Boolean).join(', '):''};
 shipment.origin_label=s.origin_place_label||label(s.origin_location_id);shipment.destination_label=s.destination_place_label||label(s.destination_location_id);shipment.last_location=map.get(Number(s.last_known_location_id))||null;
 return true
}
function renderDetails(){
 $('title').textContent='Shipment '+(shipment.shipment_number||('#'+shipment.id));
 $('subtitle').textContent='Shipment record verified inside your authorized customer organization. The current status is taken from KRIM’s database.';
 $('fields').replaceChildren();
 field('Shipment reference',shipment.shipment_number||('#'+shipment.id));field('Operational status',String(shipment.status||'unknown').replace(/_/g,' '));field('Origin',place(shipment.origin_label));field('Destination',place(shipment.destination_label));field('Cargo description',shipment.goods_description);field('Weight',shipment.total_weight_kg==null?'Not recorded':Number(shipment.total_weight_kg).toLocaleString()+' kg');field('Transport mode',shipment.requested_transport_mode);field('Route type',shipment.requested_route_type);field('Created',date(shipment.created_at));field('Last updated',date(shipment.updated_at));field('Estimated delivery',date(shipment.estimated_delivery_at));field('Actual delivery',date(shipment.actual_delivery_at));
 $('actions').replaceChildren();
 [['Timeline','public/customer-os/customer-services/shipment-timeline.html'],['Tracking','public/customer-os/customer-services/tracking-map.html'],['Quote comparison','public/shipper/quote-comparison.html']].forEach(([label,url])=>{const a=node('a','btn',label+' →');a.href=path(url)+(url.includes('quote-comparison')?'?shipment_id='+encodeURIComponent(shipment.id):'?shipment_id='+encodeURIComponent(shipment.id));$('actions').appendChild(a)});
 say('Shipment ownership verified. Quote, partner assignment, payment and delivery evidence are separate lifecycle records.')
}
function renderEvents(rows,emptyText){
 const root=$('events');root.replaceChildren();
 if(!rows.length){root.appendChild(node('div','empty',emptyText));return}
 rows.sort((a,b)=>new Date(b.when||0)-new Date(a.when||0));
 rows.forEach(e=>{const card=node('article','event');const top=node('div','event-top');top.append(node('strong','',e.title||'Shipment event'),node('span','time',date(e.when)));card.appendChild(top);if(e.location)card.appendChild(node('p','event-meta','Location: '+e.location));if(e.source)card.appendChild(node('p','event-meta','Source: '+e.source));if(e.notes)card.appendChild(node('p','event-meta',e.notes));if(e.coordinates){const a=node('a','map-link','Open recorded coordinates ↗');a.href='https://www.openstreetmap.org/?mlat='+encodeURIComponent(e.coordinates.lat)+'&mlon='+encodeURIComponent(e.coordinates.lng)+'#map=12/'+encodeURIComponent(e.coordinates.lat)+'/'+encodeURIComponent(e.coordinates.lng);a.target='_blank';a.rel='noopener noreferrer';card.appendChild(a)}root.appendChild(card)})
}
async function loadTimeline(){
 $('title').textContent='Shipment timeline · '+(shipment.shipment_number||('#'+shipment.id));$('subtitle').textContent='Events are shown newest first in '+userTimezone+' ('+timezoneSource+'). The timeline uses recorded KRIM status, tracking and milestone records.';
 const [historyResult,trackingResult,milestoneResult]=await Promise.all([
  client.from('krim_shipment_status_history').select('previous_status,new_status,change_source,notes,created_at').eq('shipment_id',shipment.id).order('created_at',{ascending:false}).limit(100),
  client.from('krim_tracking_events').select('event_type,event_time,source_type,source_reference,latitude,longitude,location_id,created_at,metadata').eq('shipment_id',shipment.id).order('event_time',{ascending:false}).limit(100),
  client.from('krim_shipment_milestones').select('milestone_type,planned_at,actual_at,status,notes,location_id,created_at').eq('shipment_id',shipment.id).order('created_at',{ascending:false}).limit(100)
 ]);
 const locIds=[...new Set([...(trackingResult.data||[]).map(e=>Number(e.location_id)),...(milestoneResult.data||[]).map(e=>Number(e.location_id))].filter(Number.isSafeInteger))];
 let locations=[],locationError=null;if(locIds.length){const r=await client.from('krim_locations').select('id,city,state_region,region,location_code').in('id',locIds);locations=r.data||[];locationError=r.error}
 const map=new Map(locations.map(l=>[Number(l.id),[l.city,l.state_region||l.region,l.location_code].filter(Boolean).join(', ')]));
 const events=[];
 (historyResult.data||[]).forEach(e=>events.push({title:(e.previous_status||'start')+' → '+(e.new_status||'status update'),when:e.created_at,source:e.change_source,notes:e.notes}));
 (trackingResult.data||[]).forEach(e=>events.push({title:String(e.event_type||'tracking update').replace(/_/g,' '),when:e.event_time||e.created_at,source:[e.source_type,e.source_reference].filter(Boolean).join(' · '),location:map.get(Number(e.location_id))||'',coordinates:e.latitude!==null&&e.latitude!==undefined&&e.longitude!==null&&e.longitude!==undefined&&Number.isFinite(Number(e.latitude))&&Number.isFinite(Number(e.longitude))?{lat:Number(e.latitude),lng:Number(e.longitude)}:null,notes:''}));
 (milestoneResult.data||[]).forEach(e=>events.push({title:'Milestone · '+String(e.milestone_type||'update').replace(/_/g,' '),when:e.actual_at||e.planned_at||e.created_at,source:'Milestone status: '+String(e.status||'not recorded').replace(/_/g,' '),location:map.get(Number(e.location_id))||'',notes:e.notes||''}));
 renderEvents(events,'No shipment timeline events are currently available. KRIM will not invent milestones or tracking updates.');
 const errors=[historyResult.error,trackingResult.error,milestoneResult.error,locationError].filter(Boolean);
 if(errors.length)say('Shipment ownership is verified, but one or more event sources could not be loaded due to backend permissions or availability. Displayed events are only records returned by KRIM.','warn');
 else say('Loaded '+events.length+' recorded status, tracking and milestone events for this shipment.')
}
async function loadTracking(){
 $('title').textContent='Tracking & visibility · '+(shipment.shipment_number||('#'+shipment.id));
 const {data:events,error}=await client.from('krim_tracking_events').select('event_type,event_time,source_type,source_reference,latitude,longitude,location_id,created_at').eq('shipment_id',shipment.id).order('event_time',{ascending:false}).limit(100);if(error)throw error;const orderedEvents=[...(events||[])].sort((a,b)=>new Date(b.event_time||b.created_at||0)-new Date(a.event_time||a.created_at||0));
 const ids=[...new Set([Number(shipment.last_known_location_id),...(events||[]).map(e=>Number(e.location_id))].filter(Number.isSafeInteger))];
 const {data:locs,error:le}=ids.length?await client.from('krim_locations').select('id,city,state_region,region,location_code,latitude,longitude').in('id',ids):{data:[],error:null};if(le)throw le;
 const map=new Map((locs||[]).map(l=>[Number(l.id),l]));
 const last=map.get(Number(shipment.last_known_location_id));
 $('fields').replaceChildren();field('Shipment reference',shipment.shipment_number||('#'+shipment.id));field('Shipment status',String(shipment.status||'unknown').replace(/_/g,' '));field('Last recorded location',last?[last.city,last.state_region||last.region,last.location_code].filter(Boolean).join(', '):'No recorded location');field('Latest event',events?.[0]?.event_type?String(events[0].event_type).replace(/_/g,' '):'No tracking events');field('Latest event time',date(events?.[0]?.event_time||events?.[0]?.created_at));field('Verified event count',String((events||[]).length));field('Latest recorded event',date(orderedEvents[0]?.event_time||orderedEvents[0]?.created_at));field('Tracking freshness',trackingFreshness(orderedEvents[0]?.event_time||orderedEvents[0]?.created_at));field('Display time zone',userTimezone+' · '+timezoneSource);
 const rows=orderedEvents.map(e=>{const loc=map.get(Number(e.location_id));const lat=Number(e.latitude),lng=Number(e.longitude);return{title:String(e.event_type||'tracking update').replace(/_/g,' '),when:e.event_time||e.created_at,source:[e.source_type,e.source_reference].filter(Boolean).join(' · '),location:loc?[loc.city,loc.state_region||loc.region,loc.location_code].filter(Boolean).join(', '):'',coordinates:e.latitude!==null&&e.latitude!==undefined&&e.longitude!==null&&e.longitude!==undefined&&Number.isFinite(lat)&&Number.isFinite(lng)?{lat,lng}:null}});
 renderEvents(rows,'No verified tracking events have been recorded yet. The page does not fabricate GPS data or a live position.');
 say((events||[]).length?'Tracking event records loaded from KRIM. Coordinates are displayed only when stored on an event.':'No tracking events are available for this shipment yet.')
}
async function init(){
 $('details-link').href=path('public/customer-os/customer-services/shipment-details.html')+'?shipment_id='+encodeURIComponent(shipmentId||'');
 $('timeline-link').href=path('public/customer-os/customer-services/shipment-timeline.html')+'?shipment_id='+encodeURIComponent(shipmentId||'');
 $('tracking-link').href=path('public/customer-os/customer-services/tracking-map.html')+'?shipment_id='+encodeURIComponent(shipmentId||'');
 if(!await access())return;await loadUserPreferences();if(!await loadShipment())return;
 if(view==='details')renderDetails();else if(view==='timeline')await loadTimeline();else await loadTracking()
}
init().catch(e=>{console.error(e);$('title').textContent='Unable to load shipment';say((e&&e.message)||'Shipment data could not be loaded. No operational state was assumed.','error')});
})();