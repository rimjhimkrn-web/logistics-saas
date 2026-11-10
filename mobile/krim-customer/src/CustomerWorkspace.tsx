import React, { useCallback, useEffect, useState } from "react";
import { ActivityIndicator, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import * as SecureStore from "expo-secure-store";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./lib/supabase";
import {
  loadCustomerOrganizations,
  loadCustomerShipments,
  loadCustomerQuotes,
  loadShipmentTracking,
  type CustomerOrganization,
  type CustomerShipment,
  type CustomerQuote,
} from "./lib/customerRepository";

type Props = { session: Session; onSignOut: () => void };
type Tracking = { shipment?: Record<string, unknown>; events?: Array<Record<string, unknown>>; milestones?: Array<Record<string, unknown>> };

const navy = "#071A35", blue = "#2366D9", teal = "#078B83", muted = "#687A90", line = "#E0E7F0";
const tabs = ["Home", "Book", "Shipments", "Quotes", "Track", "Account"] as const;
type Tab = typeof tabs[number];

export default function CustomerWorkspace({ session, onSignOut }: Props) {
  const [tab, setTab] = useState<Tab>("Home");
  const [organizations, setOrganizations] = useState<CustomerOrganization[]>([]);
  const [organizationId, setOrganizationId] = useState<number | null>(null);
  const [shipments, setShipments] = useState<CustomerShipment[]>([]);
  const [quotes, setQuotes] = useState<CustomerQuote[]>([]);
  const [tracking, setTracking] = useState<Tracking | null>(null);
  const [trackingShipment, setTrackingShipment] = useState("");
  const [loadingOrganizations, setLoadingOrganizations] = useState(true);
  const [loadingData, setLoadingData] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [acceptingQuoteId, setAcceptingQuoteId] = useState<number | null>(null);

  const refreshOrganizations = useCallback(async () => {
    if (!supabase) return;
    setLoadingOrganizations(true);
    setError("");
    try {
      const rows = await loadCustomerOrganizations(supabase, session.user.id);
      setOrganizations(rows);
      setOrganizationId((current) => rows.some((x) => x.id === current) ? current : (rows[0]?.id ?? null));
    } catch {
      setError("We could not load your authorized organizations. Please retry or contact KRIM support.");
    } finally {
      setLoadingOrganizations(false);
    }
  }, [session.user.id]);

  useEffect(() => { void refreshOrganizations(); }, [refreshOrganizations]);

  const refreshWorkspace = useCallback(async () => {
    if (!supabase || organizationId === null) {
      setShipments([]);
      setQuotes([]);
      return;
    }
    setLoadingData(true);
    setError("");
    try {
      const [shipmentRows, quoteRows] = await Promise.all([
        loadCustomerShipments(supabase, organizationId),
        loadCustomerQuotes(supabase, organizationId),
      ]);
      setShipments(shipmentRows);
      setQuotes(quoteRows);
    } catch {
      setError("Some workspace data could not be loaded. Access remains protected by KRIM authorization policies.");
    } finally {
      setLoadingData(false);
    }
  }, [organizationId]);

  useEffect(() => { void refreshWorkspace(); }, [refreshWorkspace]);

  const acceptQuote = async (quoteId: number) => {
    if (!supabase || organizationId === null || acceptingQuoteId !== null) return;
    setAcceptingQuoteId(quoteId); setError(""); setNotice("");
    try {
      const { error: rpcError } = await supabase.rpc("krim_accept_global_quote", { p_quote_id: quoteId });
      if (rpcError) throw rpcError;
      setNotice("Quote accepted. Your shipment is moving to the confirmation workflow.");
      await refreshWorkspace();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Quote could not be accepted. Refresh and check its current status.");
    } finally { setAcceptingQuoteId(null); }
  };

  const showTracking = async (shipmentNumber: string) => {
    if (!supabase) return;
    setTracking(null);
    setTrackingShipment(shipmentNumber);
    setTab("Track");
    setLoadingData(true);
    setError("");
    try {
      const result = await loadShipmentTracking(supabase, shipmentNumber);
      setTracking(result as Tracking);
    } catch {
      setError("Tracking is unavailable or your account is not authorized to view this shipment.");
    } finally {
      setLoadingData(false);
    }
  };

  const selectedOrganization = organizations.find((x) => x.id === organizationId);
  const openQuotes = quotes.filter((q) => q.status === "sent" && new Date(q.valid_until).getTime() > Date.now()).length;

  return (
    <View style={s.safe}>
      <View style={s.top}>
        <View><Text style={s.topBrand}>KRIM CUSTOMER</Text><Text style={s.topSub}>GLOBAL LOGISTICS OPERATING SYSTEM</Text></View>
        <Text style={s.signed}>● SECURE SESSION</Text>
      </View>
      <ScrollView contentContainerStyle={s.content}>
        <View style={s.info}><Text style={s.infoText}>LIVE DATA · SHIPMENT REQUESTS & TRACKING</Text></View>
        {!!error && <View style={s.errorBox}><Text style={s.errorText}>{error}</Text></View>}
        {!!notice && <View style={s.info}><Text style={s.infoText}>{notice}</Text></View>}

        <View style={s.panel}>
          <Text style={s.kicker}>AUTHORIZED ORGANIZATION</Text>
          {loadingOrganizations ? <ActivityIndicator color={blue}/> :
            organizations.length === 0 ? <Text style={s.muted}>No active organization membership was found for this account. Ask your organization administrator to invite you with the correct role.</Text> :
            <>
              <Text style={s.orgName}>{selectedOrganization?.display_name || selectedOrganization?.legal_name || "Select organization"}</Text>
              <Text style={s.tiny}>{selectedOrganization?.organization_type || "Organization"} · {selectedOrganization?.role || "Member"} · {selectedOrganization?.default_currency_code || "Currency not configured"} · {selectedOrganization?.timezone || "Timezone not configured"}</Text>
              <View style={s.orgChips}>{organizations.map((org) =>
                <Pressable key={org.id} onPress={() => { setOrganizationId(org.id); setTracking(null); }} style={[s.chip, organizationId === org.id && s.chipActive]}>
                  <Text style={[s.chipText, organizationId === org.id && s.chipTextActive]}>{org.display_name || org.legal_name}</Text>
                </Pressable>
              )}</View>
            </>}
        </View>

        {tab === "Home" && <>
          <Header kicker="CUSTOMER CONTROL CENTRE" title="Your logistics workspace" sub="Verified account information from the KRIM operating system."/>
          <View style={s.metrics}>
            <Metric title="Visible shipments" value={String(shipments.length)} detail="RLS-authorized records"/>
            <Metric title="Valid sent quotes" value={String(openQuotes)} detail="Not yet accepted or expired"/>
          </View>
          <View style={s.panel}>
            <Text style={s.panelTitle}>Recent shipments</Text>
            {loadingData ? <ActivityIndicator color={blue}/> : shipments.slice(0, 4).length ? shipments.slice(0, 4).map((x) =>
              <ShipmentRow key={x.id} shipment={x} onPress={() => void showTracking(x.shipment_number)}/>
            ) : <Text style={s.muted}>No shipment records are currently visible for this organization.</Text>}
            <Action title="View all shipments" onPress={() => setTab("Shipments")} secondary/>
          </View>
          <View style={s.panel}>
            <Text style={s.panelTitle}>How KRIM protects operations</Text>
            <Bullet text="Organization membership is checked by the backend."/>
            <Bullet text="Shipment and quote reads use existing row-level security."/>
            <Bullet text="Operational changes remain disabled until end-to-end controls are verified."/>
          </View>
        </>}

        {tab === "Book" && <CustomerBooking organizationId={organizationId} onCreated={async () => { await refreshWorkspace(); setTab("Shipments"); setNotice("Shipment request created. Check its reference in My Shipments; service and price are not confirmed yet."); }}/>}

        {tab === "Shipments" && <>
          <Header kicker="SHIPMENT VISIBILITY" title="Your shipments" sub="Only records authorized for the selected organization are shown."/>
          {loadingData ? <ActivityIndicator color={blue}/> : shipments.length ? shipments.map((x) => <ShipmentRow key={x.id} shipment={x} onPress={() => void showTracking(x.shipment_number)}/>) : <Empty title="No visible shipments" body="No shipments are currently available for this organization, or your role does not have access."/>}
        </>}

        {tab === "Quotes" && <>
          <Header kicker="COMMERCIAL VISIBILITY" title="Quotes" sub="Amounts and currencies are displayed only from authorized KRIM quote records."/>
          {loadingData ? <ActivityIndicator color={blue}/> : quotes.length ? quotes.map((q) => <View key={q.id} style={s.panel}>
            <Text style={s.panelTitle}>Quote #{q.id}</Text>
            <Text style={s.amount}>{Number(q.amount).toLocaleString(undefined, { maximumFractionDigits: 2 })} {q.currency_code}</Text>
            <Text style={s.tiny}>Shipment ID {q.shipment_id} · Status: {q.status}</Text>
            <Text style={s.tiny}>Valid until: {new Date(q.valid_until).toLocaleString()}</Text>
            {q.status === "sent" && new Date(q.valid_until).getTime() > Date.now() ? <Action title={acceptingQuoteId === q.id ? "Accepting…" : "Accept quote"} onPress={() => void acceptQuote(q.id)} /> : <Text style={s.tiny}>This quote is not currently available for acceptance.</Text>}
          </View>) : <Empty title="No visible quotes" body="Confirmed quotes will appear here when available to your organization."/>}
        </>}

        {tab === "Track" && <>
          <Header kicker="AUTHORIZED TRACKING" title="Shipment tracking" sub="Select a shipment to retrieve its verified milestones."/>
          {trackingShipment ? <View style={s.panel}>
            <Text style={s.panelTitle}>Tracking: {trackingShipment}</Text>
            {loadingData ? <ActivityIndicator color={blue}/> : tracking ? <>
              <Text style={s.body}>{String(tracking.shipment?.status || "Status unavailable")}</Text>
              {(tracking.events || []).map((event, i) => <Bullet key={String(event.id ?? i)} text={String(event.event_type || "Shipment event") + " · " + (event.event_time ? new Date(String(event.event_time)).toLocaleString() : "Time not provided")}/>)}
              {(tracking.milestones || []).map((m, i) => <Bullet key={String(m.id ?? "m"+i)} text={String(m.milestone_type || "Milestone") + " · " + String(m.status || "Status unavailable")}/>)}
              {!tracking.events?.length && !tracking.milestones?.length && <Text style={s.muted}>No execution events have been recorded yet.</Text>}
            </> : <Text style={s.muted}>Tracking details have not been loaded.</Text>}
          </View> : <Empty title="Choose a shipment" body="Open a shipment from the Shipments tab to load its authorized tracking timeline."/>}
        </>}

        {tab === "Account" && <>
          <Header kicker="ACCOUNT SECURITY" title="Your account" sub={session.user.email || "Authenticated KRIM account"}/>
          <View style={s.panel}>
            <Text style={s.panelTitle}>Session and organization access</Text>
            <Text style={s.body}>Signed in successfully. Your app reads only active organization memberships visible to your authenticated account. Database policies remain the source of authorization.</Text>
            <Action title="Refresh account data" onPress={() => { void refreshOrganizations(); void refreshWorkspace(); }} secondary/>
            <Action title="Sign out securely" onPress={onSignOut}/>
          </View>
          <View style={s.panel}><Text style={s.panelTitle}>KRIM</Text><Text style={s.body}>Knowledge · Reliability · Integration · Movement</Text><Text style={s.tiny}>Global-ready architecture · Market availability requires local partner and compliance verification.</Text></View>
        </>}
      </ScrollView>
      <View style={s.nav}>{tabs.map((item) => <Pressable key={item} onPress={() => setTab(item)} accessibilityRole="tab" accessibilityState={{selected: tab === item}} style={s.navItem}>
        <Text style={[s.navIcon, tab === item && {color: blue}]}>{({Home:"⌂",Book:"+",Shipments:"▤",Quotes:"≋",Track:"◎",Account:"○"} as Record<Tab,string>)[item]}</Text>
        <Text style={[s.navLabel, tab === item && {color: blue}]}>{item}</Text>
      </Pressable>)}</View>
    </View>
  );
}

function Header({kicker,title,sub}:{kicker:string;title:string;sub:string}) { return <View style={s.header}><Text style={s.kicker}>{kicker}</Text><Text style={s.title}>{title}</Text><Text style={s.muted}>{sub}</Text></View>; }
function Metric({title,value,detail}:{title:string;value:string;detail:string}) { return <View style={s.metric}><Text style={s.muted}>{title}</Text><Text style={s.metricValue}>{value}</Text><Text style={s.tiny}>{detail}</Text></View>; }
function ShipmentRow({shipment,onPress}:{shipment:CustomerShipment;onPress:()=>void}) { return <Pressable onPress={onPress} style={s.shipment}><View style={{flex:1}}><Text style={s.panelTitle}>{shipment.shipment_number}</Text><Text style={s.body}>{shipment.origin_place_label || "Origin not specified"} → {shipment.destination_place_label || "Destination not specified"}</Text><Text style={s.tiny}>{shipment.requested_transport_mode || "Mode not specified"} · {shipment.status}</Text></View><Text style={s.open}>View ›</Text></Pressable>; }
function Bullet({text}:{text:string}) { return <View style={s.bullet}><Text style={s.bulletDot}>•</Text><Text style={s.body}>{text}</Text></View>; }
function Empty({title,body}:{title:string;body:string}) { return <View style={s.panel}><Text style={s.panelTitle}>{title}</Text><Text style={s.muted}>{body}</Text></View>; }
function Action({title,onPress,secondary=false}:{title:string;onPress:()=>void;secondary?:boolean}) { return <Pressable accessibilityRole="button" onPress={onPress} style={[s.action,secondary&&s.actionSecondary]}><Text style={[s.actionText,secondary&&{color:navy}]}>{title}</Text></Pressable>; }

const s = StyleSheet.create({
 safe:{flex:1,backgroundColor:"#F3F6FA"}, top:{backgroundColor:navy,paddingHorizontal:17,paddingVertical:14,flexDirection:"row",alignItems:"center",justifyContent:"space-between"},
 topBrand:{fontSize:14,fontWeight:"900",letterSpacing:1,color:"#fff"},topSub:{fontSize:14,letterSpacing:1.5,color:"#B9C9DA",marginTop:3},signed:{fontSize:14,fontWeight:"900",color:"#B9F2D7"},
 content:{padding:15,paddingBottom:28},info:{padding:12,borderRadius:11,backgroundColor:"#EAF2FF",marginBottom:12},infoText:{fontSize:14,lineHeight:16,color:"#234A7D"},
 errorBox:{padding:12,borderRadius:11,backgroundColor:"#FDECEC",marginBottom:12},errorText:{fontSize:14,lineHeight:16,color:"#9C2525"},
 panel:{backgroundColor:"#fff",borderWidth:1,borderColor:line,borderRadius:15,padding:15,marginBottom:12},kicker:{fontSize:14,fontWeight:"900",letterSpacing:1.4,color:teal,marginBottom:7},orgName:{fontSize:17,fontWeight:"900",color:navy},tiny:{fontSize:14,color:muted,marginTop:4,lineHeight:15},muted:{fontSize:14,color:muted,lineHeight:19},orgChips:{flexDirection:"row",flexWrap:"wrap",gap:7,marginTop:12},chip:{borderWidth:1,borderColor:line,borderRadius:18,paddingHorizontal:11,paddingVertical:8},chipActive:{backgroundColor:blue,borderColor:blue},chipText:{fontSize:14,fontWeight:"800",color:navy},chipTextActive:{color:"#fff"},
 header:{marginBottom:14},title:{fontSize:25,fontWeight:"900",letterSpacing:-.6,color:navy,marginBottom:5},metrics:{flexDirection:"row",gap:10,marginBottom:12},metric:{flex:1,backgroundColor:"#fff",borderWidth:1,borderColor:line,borderRadius:14,padding:13},metricValue:{fontSize:21,fontWeight:"900",color:navy,marginTop:7},panelTitle:{fontSize:14,fontWeight:"900",color:navy,marginBottom:7},body:{fontSize:14,color:muted,lineHeight:17},shipment:{flexDirection:"row",alignItems:"center",paddingVertical:12,borderBottomWidth:1,borderBottomColor:"#EEF1F5"},open:{fontSize:14,fontWeight:"900",color:blue},amount:{fontSize:20,fontWeight:"900",color:navy},bullet:{flexDirection:"row",gap:8,marginTop:8},bulletDot:{fontSize:16,color:teal},action:{minHeight:43,backgroundColor:blue,borderRadius:10,alignItems:"center",justifyContent:"center",paddingHorizontal:12,marginTop:10},actionSecondary:{backgroundColor:"#fff",borderWidth:1,borderColor:line},actionText:{fontSize:14,fontWeight:"900",color:"#fff"},
 nav:{flexDirection:"row",backgroundColor:"#fff",borderTopWidth:1,borderTopColor:line,paddingTop:8,paddingBottom:Platform.OS==="ios"?18:9},navItem:{flex:1,alignItems:"center",gap:3},navIcon:{fontSize:19,color:"#8391A4"},navLabel:{fontSize:14,fontWeight:"800",color:"#8391A4"},
 choice:{borderWidth:1,borderColor:line,borderRadius:18,paddingHorizontal:10,paddingVertical:8,marginRight:6,marginBottom:7},choiceActive:{backgroundColor:blue,borderColor:blue},choiceText:{fontSize:14,fontWeight:"800",color:navy},choiceTextActive:{color:"#fff"},choiceRow:{flexDirection:"row",flexWrap:"wrap",marginTop:6,marginBottom:8},fieldLabel:{fontSize:14,fontWeight:"900",color:navy,marginTop:13,marginBottom:6},input:{borderWidth:1,borderColor:line,borderRadius:11,paddingHorizontal:12,paddingVertical:11,fontSize:15,color:navy,backgroundColor:"#FBFCFE",marginBottom:7},result:{padding:11,borderBottomWidth:1,borderBottomColor:line,backgroundColor:"#F6F9FD",borderRadius:8,marginBottom:4},resultText:{fontSize:14,color:navy},smallNote:{fontSize:13,color:muted,lineHeight:18,marginTop:9},bookingMessage:{fontSize:14,fontWeight:"700",color:teal,marginTop:10}
});

type Place = { name: string; city: string; state: string; country: string; country_code: string; latitude: number; longitude: number; display_name: string; place_type: string };
type PlaceFeature = { properties?: Record<string, unknown>; geometry?: { coordinates?: number[] } };
function CustomerBooking({ organizationId, onCreated }: { organizationId: number | null; onCreated: () => Promise<void> }) {
  const [originQuery,setOriginQuery]=useState(""); const [destinationQuery,setDestinationQuery]=useState("");
  const [origin,setOrigin]=useState<Place|null>(null); const [destination,setDestination]=useState<Place|null>(null);
  const [originResults,setOriginResults]=useState<Place[]>([]); const [destinationResults,setDestinationResults]=useState<Place[]>([]);
  const [goods,setGoods]=useState(""); const [weight,setWeight]=useState(""); const [mode,setMode]=useState("multimodal");
  const [routeType,setRouteType]=useState("door_to_door"); const [searching,setSearching]=useState<"origin"|"destination"|null>(null);
  const [submitting,setSubmitting]=useState(false); const [attempted,setAttempted]=useState(false); const [message,setMessage]=useState("");
  const [bookingKey,setBookingKey]=useState<string|null>(null);
  const makeId=()=>{const c=(globalThis as any).crypto;if(c&&typeof c.randomUUID==="function")return c.randomUUID();return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,ch=>{const r=Math.random()*16|0;return(ch==="x"?r:(r&3|8)).toString(16);});};
  const searchPlaces=async(kind:"origin"|"destination",query:string)=>{
    if(query.trim().length<3){kind==="origin"?setOriginResults([]):setDestinationResults([]);return;}
    setSearching(kind);
    try{
      const response=await fetch("https://photon.komoot.io/api/?q="+encodeURIComponent(query.trim())+"&limit=6&lang=en",{headers:{Accept:"application/json"}});
      if(!response.ok)throw new Error("Global place search is unavailable. Try again.");
      const json=await response.json() as {features?:PlaceFeature[]};
      const places=(json.features||[]).map(feature=>{
        const p=feature.properties||{};const coords=feature.geometry?.coordinates||[];
        const code=String(p.countrycode||p.country_code||"").toUpperCase();
        const city=String(p.city||p.town||p.village||p.municipality||p.county||p.name||"").trim();
        const country=String(p.country||"").trim();
        const lat=Number(coords[1]),lon=Number(coords[0]);
        if(!city||!country||!/^[A-Z]{2}$/.test(code)||!Number.isFinite(lat)||!Number.isFinite(lon))return null;
        const state=String(p.state||p.region||"").slice(0,160);
        const name=String(p.name||city).slice(0,160);
        const label=[name,city,state,country].filter((v,i,a)=>v&&a.findIndex(x=>x.toLowerCase()===v.toLowerCase())===i).join(", ");
        return {name:city,city,state,country,country_code:code,latitude:lat,longitude:lon,display_name:label.slice(0,240),place_type:String(p.osm_value||p.type||"place").slice(0,40)} as Place;
      }).filter((x):x is Place=>!!x);
      if(kind==="origin")setOriginResults(places);else setDestinationResults(places);
    }catch(e){setMessage(e instanceof Error?e.message:"Place search failed.");}
    finally{setSearching(null);}
  };
  const pick=(kind:"origin"|"destination",place:Place)=>{
    if(kind==="origin"){setOrigin(place);setOriginQuery(place.display_name);setOriginResults([]);}
    else{setDestination(place);setDestinationQuery(place.display_name);setDestinationResults([]);}
  };
  const selectStyle=(active:boolean)=>[s.choice,active&&s.choiceActive];
  const submit=async()=>{
    if(!supabase||organizationId===null){setMessage("Select an active customer organization first.");return;}
    if(!origin||!destination){setMessage("Search and select both locations from the global results.");return;}
    if(origin.latitude===destination.latitude&&origin.longitude===destination.longitude){setMessage("Origin and destination must be different places.");return;}
    if(routeType==="domestic"&&origin.country_code!==destination.country_code){setMessage("Domestic movement requires both places in the same country.");return;}
    if(routeType==="cross_border"&&origin.country_code===destination.country_code){setMessage("Cross-border movement requires different countries.");return;}
    const kg=Number(weight);if(!goods.trim()||goods.trim().length>500||!Number.isFinite(kg)||kg<=0||kg>100000000){setMessage("Enter goods details and a valid weight greater than zero.");return;}
    setSubmitting(true);setAttempted(true);setMessage("Submitting securely…");
    try{
      let requestId=bookingKey;
      if(!requestId){const keyName="krim_customer_booking_request_"+organizationId;requestId=await SecureStore.getItemAsync(keyName);if(!requestId){requestId=makeId();await SecureStore.setItemAsync(keyName,requestId);}setBookingKey(requestId);}
      const {data,error}=await supabase.rpc("krim_create_global_shipment_idempotent",{
        p_customer_organization_id:organizationId,p_origin_place:origin,p_destination_place:destination,
        p_goods_description:goods.trim(),p_total_weight_kg:kg,p_transport_mode:mode,p_route_type:routeType,p_booking_request_id:requestId
      });
      if(error)throw error;
      const row=Array.isArray(data)?data[0]:data as any;const id=row?.id??row?.shipment_id;
      if(!id)throw new Error("KRIM returned no shipment reference. Check My Shipments before retrying.");
      await SecureStore.deleteItemAsync("krim_customer_booking_request_"+organizationId);
      setBookingKey(null);setMessage("Shipment request created. Reference #"+id+". No carrier, price or dispatch is confirmed yet.");
      await onCreated();
    }catch(e){setMessage(e instanceof Error?e.message:"Shipment request failed. If the connection timed out, check My Shipments before retrying.");}
    finally{setSubmitting(false);}
  };
  return <View>
    <Header kicker="NEW SHIPMENT" title="Create a shipment request" sub="Choose locations and cargo. Coverage, partner capacity and price are checked separately."/>
    {organizationId===null?<Empty title="Organization required" body="Select an active customer organization before booking."/>:<View style={s.panel}>
      <Text style={s.kicker}>ROUTE</Text>
      <Text style={s.fieldLabel}>Origin · Search worldwide</Text>
      <TextInput value={originQuery} onChangeText={v=>{setOriginQuery(v);setOrigin(null);void searchPlaces("origin",v);}} placeholder="City, airport, port or address" style={s.input} editable={!attempted}/>
      {searching==="origin"&&<ActivityIndicator color={blue}/>}
      {originResults.map((p,i)=><Pressable key={"o"+i} style={s.result} onPress={()=>pick("origin",p)}><Text style={s.resultText}>{p.display_name}</Text></Pressable>)}
      <Text style={s.fieldLabel}>Destination · Search worldwide</Text>
      <TextInput value={destinationQuery} onChangeText={v=>{setDestinationQuery(v);setDestination(null);void searchPlaces("destination",v);}} placeholder="City, airport, port or address" style={s.input} editable={!attempted}/>
      {searching==="destination"&&<ActivityIndicator color={blue}/>}
      {destinationResults.map((p,i)=><Pressable key={"d"+i} style={s.result} onPress={()=>pick("destination",p)}><Text style={s.resultText}>{p.display_name}</Text></Pressable>)}
      <Text style={s.fieldLabel}>Route type</Text>
      <View style={s.choiceRow}>{[["door_to_door","Door to door"],["domestic","Domestic"],["cross_border","Cross-border"]].map(([v,label])=><Pressable key={v} disabled={attempted} onPress={()=>setRouteType(v)} style={selectStyle(routeType===v)}><Text style={[s.choiceText,routeType===v&&s.choiceTextActive]}>{label}</Text></Pressable>)}</View>
      <Text style={s.fieldLabel}>Preferred mode</Text>
      <View style={s.choiceRow}>{[["multimodal","Multimodal"],["road","Road"],["rail","Rail"],["air","Air"],["ocean","Ocean"],["warehouse_transfer","Warehouse"]].map(([v,label])=><Pressable key={v} disabled={attempted} onPress={()=>setMode(v)} style={selectStyle(mode===v)}><Text style={[s.choiceText,mode===v&&s.choiceTextActive]}>{label}</Text></Pressable>)}</View>
      <Text style={s.fieldLabel}>Goods description</Text><TextInput value={goods} onChangeText={setGoods} editable={!attempted} placeholder="What are you shipping?" style={s.input} maxLength={500}/>
      <Text style={s.fieldLabel}>Gross weight (kg)</Text><TextInput value={weight} onChangeText={setWeight} editable={!attempted} placeholder="e.g. 1250" keyboardType="decimal-pad" style={s.input}/>
      <Text style={s.smallNote}>Geographic search does not confirm service availability. Do not treat this request as a confirmed booking.</Text>
      {!!message&&<Text style={s.bookingMessage}>{message}</Text>}
      <Action title={submitting?"Submitting…":attempted?"Retry same request":"Create shipment request"} onPress={()=>void submit()}/>
      {attempted&&<Text style={s.smallNote}>Retry uses the same secure request reference to prevent duplicate shipments. Check My Shipments before starting another request.</Text>}
    </View>}
  </View>;
}
