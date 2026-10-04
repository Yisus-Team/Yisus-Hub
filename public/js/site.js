document.getElementById('changelogSearch').addEventListener('input',e=>{const q=e.target.value.trim().toLowerCase();document.querySelectorAll('#changelogList .changelog-item').forEach(item=>item.hidden=!item.textContent.toLowerCase().includes(q))});
document.getElementById('copyBtn').addEventListener('click',async()=>{const text=document.getElementById('scriptCode').textContent;try{await navigator.clipboard.writeText(text)}catch(e){const t=document.createElement('textarea');t.value=text;document.body.appendChild(t);t.select();document.execCommand('copy');t.remove()}const toast=document.getElementById('toast');toast.classList.add('show');setTimeout(()=>toast.classList.remove('show'),1300)});

const DEV_CACHE_KEY='yisus-discord-devs-v1';
const DEV_CACHE_TTL=3*60*60*1000;

function discordCdnUrl(value){try{const url=new URL(value);return url.protocol==='https:'&&url.hostname==='cdn.discordapp.com'?url.href:null}catch{return null}}
function renderDevs(list){const box=document.getElementById('devList');box.replaceChildren();list.forEach(profile=>{const card=document.createElement('article');card.className='dev-card';const banner=document.createElement('div');banner.className='dev-banner';const bannerUrl=discordCdnUrl(profile.banner);if(bannerUrl)banner.style.backgroundImage='linear-gradient(#0003,#0003),url("'+bannerUrl+'")';const identity=document.createElement('div');identity.className='dev-identity';const avatar=document.createElement('img');avatar.className='dev-avatar';avatar.alt='';const avatarUrl=discordCdnUrl(profile.avatar);if(avatarUrl){avatar.src=avatarUrl;avatar.loading='lazy'}else{avatar.hidden=true}const name=document.createElement('div');name.className='dev-name';name.textContent=profile.name;const role=document.createElement('div');role.className='dev-role';role.textContent='Desarrollador';identity.append(avatar,name,role);card.append(banner,identity);box.append(card)})}

function readDevCache(allowExpired=false){
  try{
    const cached=JSON.parse(localStorage.getItem(DEV_CACHE_KEY));
    if(!cached||!Array.isArray(cached.profiles)||!Number.isFinite(cached.savedAt))return null;
    if(!allowExpired&&Date.now()-cached.savedAt>=DEV_CACHE_TTL)return null;
    return cached.profiles;
  }catch{return null}
}

function writeDevCache(profiles){
  try{localStorage.setItem(DEV_CACHE_KEY,JSON.stringify({savedAt:Date.now(),profiles}))}catch{}
}

async function loadDevs(){
  let profiles=readDevCache();

  if(!profiles){
    try{
      const response=await fetch('/api/discord',{headers:{Accept:'application/json'}});
      if(!response.ok)throw new Error('Discord lookup failed');
      const data=await response.json();
      if(!Array.isArray(data.profiles)||!data.profiles.length)throw new Error('Invalid Discord response');
      profiles=data.profiles;
      writeDevCache(profiles);
    }catch{
      profiles=readDevCache(true);
    }
  }

  const loadedProfiles=(profiles||[]).filter(Boolean);
  if(!loadedProfiles.length){document.getElementById('devCount').textContent='No disponible';document.getElementById('devList').textContent='No se pudieron cargar los perfiles.';return}
  document.getElementById('devCount').textContent=`${loadedProfiles.length} miembros`;
  renderDevs(loadedProfiles);
}

loadDevs();
