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

 await page.route('**/api/v1/produtos/cards?**',async route=>{
   const url=new URL(route.request().url());
   if(url.searchParams.get('lojaId')==='e2e-loja-001'){
     await new Promise(resolve=>setTimeout(resolve,1600));
     await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({content:[],last:true})});
   } else await route.continue();
 });
 await page.mouse.move(195,400);await page.mouse.wheel(0,1400);await page.waitForTimeout(600);
 await page.getByText('Loja E2E',{exact:false}).first().click();
 await page.waitForTimeout(500);
 await page.screenshot({path:'/tmp/nhac-perf-ui/store-loading.png'});
 await page.getByText('Nenhum produto disponível no momento 😥',{exact:true}).waitFor();
 if(await page.getByRole('button',{name:'Carregar mais produtos',exact:true}).count())throw Error('Lista vazia oferece página seguinte');
 await page.screenshot({path:'/tmp/nhac-perf-ui/store-empty.png'});
 console.log(JSON.stringify({loadingAndEmpty:true,errors}));
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1);});
