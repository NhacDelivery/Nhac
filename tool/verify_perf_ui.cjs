const fixturePassword = process.env.E2E_PASSWORD;
if (!fixturePassword || fixturePassword.length < 12) throw new Error('Defina E2E_PASSWORD temporária do backend isolado.');
const { chromium } = require('playwright');
require('fs').mkdirSync('/tmp/nhac-perf-ui', {recursive:true});
(async () => {
 const browser = await chromium.launch({headless:true,args:['--no-sandbox']});
 const page = await browser.newPage({viewport:{width:390,height:844}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('requestfailed',r=>errors.push(r.url()+':'+r.failure().errorText));
 await page.route('**/assets/.env',route=>route.fulfill({contentType:'text/plain',body:'API_BASE_URL=http://127.0.0.1:8089/api/v1\nE2E_MODE=true\nGOOGLE_API_KEY=\nSTRIPE_PUBLISHABLE_KEY=\nSENTRY_DSN=\n'}));
 await page.goto('http://localhost:3000');
 await page.waitForTimeout(6000);
 await page.locator('flt-semantics-placeholder').evaluate(el=>el.click()).catch(()=>{});
 await page.waitForTimeout(500);
 await page.mouse.click(195,650);
 await page.waitForTimeout(1500);
 await page.locator('input').fill('e2e.cliente@nhac.local');
 await page.mouse.click(195,789);
 await page.waitForTimeout(1800);
 await page.mouse.click(100,160);
 await page.keyboard.type(fixturePassword,{delay:20});
 await page.getByRole('button',{name:'Continuar',exact:true}).click({timeout:5000});
 await page.waitForTimeout(3500);
 await page.screenshot({path:'/tmp/nhac-perf-ui/home.png'});
 const pages=[];let failPageOne=true;
 await page.route('**/api/v1/produtos/cards?**',async route=>{
   const url=new URL(route.request().url());
   if(url.searchParams.get('lojaId')==='e2e-loja-001'){
     pages.push(url.searchParams.get('page'));
     if(url.searchParams.get('page')==='1' && failPageOne){
       failPageOne=false;
       await route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:'SERVICO_INDISPONIVEL',message:'Falha simulada'})});
       return;
     }
   }
   await route.continue();
 });
 await page.mouse.move(195,400);await page.mouse.wheel(0,1400);await page.waitForTimeout(800);
 console.log('SCROLLED',await page.locator('body').innerText());
 await page.screenshot({path:'/tmp/nhac-perf-ui/home-scrolled.png'});
 await page.getByText('Loja E2E',{exact:false}).first().click({timeout:5000});
 await page.waitForTimeout(1200);
 if(JSON.stringify(pages)!==JSON.stringify(['0']))throw Error('Cardápio buscou páginas antecipadamente: '+JSON.stringify(pages));
 await page.screenshot({path:'/tmp/nhac-perf-ui/store-first.png'});
 await page.mouse.move(195,400);await page.mouse.wheel(0,20000);await page.waitForTimeout(500);
 await page.getByRole('button',{name:'Carregar mais produtos',exact:true}).click({timeout:5000});
 await page.getByText('Não foi possível carregar mais produtos.',{exact:true}).waitFor();
 await page.screenshot({path:'/tmp/nhac-perf-ui/store-failure.png'});
 let retryFocused=false;
 for(let i=0;i<180;i++){
   await page.keyboard.press('Tab');
   const active=await page.evaluate(()=>document.activeElement?.textContent?.trim());
   if(active==='Tentar novamente'){retryFocused=true;break;}
 }
 if(!retryFocused)throw Error('Retry não alcançável pelo teclado');
 await page.screenshot({path:'/tmp/nhac-perf-ui/store-focused.png'});
 await page.keyboard.press('Enter');
 await page.waitForTimeout(1000);
 if(JSON.stringify(pages)!==JSON.stringify(['0','1','1']))throw Error('Retry avançou página ou duplicou chamadas: '+JSON.stringify(pages));
 if(await page.getByText('Não foi possível carregar mais produtos.',{exact:true}).count())throw Error('Erro permaneceu após retry bem sucedido');
 await page.screenshot({path:'/tmp/nhac-perf-ui/store-recovered.png'});
 await page.setViewportSize({width:1280,height:900});await page.waitForTimeout(600);
 await page.screenshot({path:'/tmp/nhac-perf-ui/store-desktop.png'});
 console.log(JSON.stringify({pagination:pages,partialErrorRecovered:true}));
 console.log(JSON.stringify({errors,body:await page.locator('body').innerText(),semantics:await page.locator('flt-semantics-host').innerText().catch(()=>''),inputs:await page.locator('input').count(),dom:''}));
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1);});