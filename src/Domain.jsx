import React,{useEffect,useState} from 'react';
import QRCode from 'qrcode';
import {Booking,ReservationList} from './Booking';
import {MapPanel} from './map';
const origins=[['Union Station',45.5286,-122.6765],['Pioneer Square',45.5189,-122.6793],['Downtown library',45.519,-122.6835],['Union Station',45.5286,-122.6765]];
function stops(item){const [title,lat,lng]=origins[item.id-1];return [{id:0,title,lat,lng},item]}
export function Actions(props){return <><MapPanel items={stops(props.item)} line/><p className="lean">Route schematic · {origins[props.item.id-1][0]} to {props.item.title}</p><Booking {...props}/></>}
export function Extras(){return null}
function Ticket({record,item}){
 const [code,setCode]=useState(''),[now,setNow]=useState(Date.now());
 useEffect(()=>{QRCode.toDataURL('wayloom:ticket:'+record.id,{width:220,margin:3}).then(setCode);const t=setInterval(()=>setNow(Date.now()),30000);return()=>clearInterval(t)},[record.id]);
 const local=new Intl.DateTimeFormat('sv-SE',{timeZone:'America/Los_Angeles',dateStyle:'short',timeStyle:'medium'}).format(new Date(now));
 const elapsed=(Date.parse(local.replace(' ','T')+'Z')-Date.parse(record.payload.day+'T'+item.detail+':00Z'))/60000;
 return <div><p>Departure {item.detail} · Fare USD {Number(item.price).toFixed(2)}</p>{code&&<img className="ticketcode" src={code} alt="Digital ticket QR code"/>}<details><summary>Track trip</summary><p>{elapsed<0?'Scheduled departure':elapsed<25?'Scheduled in transit':'Scheduled arrival reached'}</p><MapPanel items={stops(item)} line/><small>Timetable estimate · 25-minute demonstration service.</small></details></div>
}
export function Records(props){return <ReservationList {...props} additional={Ticket}/>}

