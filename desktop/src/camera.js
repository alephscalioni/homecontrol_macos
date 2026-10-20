const params=new URLSearchParams(location.search);
const id=params.get('id');const english=params.get('locale')==='en-US';
const img=document.getElementById('stream'),message=document.getElementById('message');
let paused=false,retries=0,timer;
const text=(pt,en)=>english?en:pt;
document.documentElement.lang=english?'en-US':'pt-BR';document.getElementById('name').textContent=params.get('name')||id;
for(const [key,pt,en] of [['pause','Pausar','Pause'],['pin','Sempre por cima','Always on top'],['size','Mudar tamanho','Change size'],['expand','Ampliar','Expand'],['close','Fechar','Close']]){const button=document.getElementById(key);button.title=button.ariaLabel=text(pt,en);}
function start(){
  clearTimeout(timer);if(paused)return;
  message.hidden=false;message.textContent=text('Conectando à câmera…','Connecting to camera…');
  img.src=`homecontrol://camera/${encodeURIComponent(id)}?live=1&t=${Date.now()}`;
}
img.onload=()=>{retries=0;message.hidden=true;img.hidden=false;};
img.onerror=()=>{if(paused)return;message.hidden=false;message.textContent=text('Transmissão indisponível. Tentando novamente…','Stream unavailable. Retrying…');timer=setTimeout(start,Math.min(15000,2000*++retries));};
document.getElementById('pause').onclick=()=>{paused=!paused;clearTimeout(timer);const button=document.getElementById('pause');button.ariaLabel=button.title=text(paused?'Retomar':'Pausar',paused?'Resume':'Pause');button.classList.toggle('selected',paused);if(paused){img.hidden=true;img.removeAttribute('src');message.hidden=false;message.textContent=text('Pausado','Paused');}else start();};
for(const action of ['pin','size','expand','close'])document.getElementById(action).onclick=async()=>{try{const result=await window.home.window(action);if(action==='pin'){document.getElementById('pin').classList.toggle('selected',result);document.getElementById('pin').setAttribute('aria-pressed',String(result));}}catch(error){message.hidden=false;message.textContent=error.message;}};
window.addEventListener('beforeunload',()=>{clearTimeout(timer);img.removeAttribute('src');});
start();
