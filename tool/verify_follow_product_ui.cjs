const { chromium } = require('playwright');
const fs = require('node:fs');
const shotDir = process.env.NHAC_UX_SHOTS || '/tmp/nhac-ux-ui';
fs.mkdirSync(shotDir, {recursive: true});
let browser;
(async () => {
 browser = await chromium.launch({headless:true,args:['--no-sandbox']});
 const page = await browser.newPage({viewport:{width:390,height:844}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('requestfailed',r=>errors.push(r.url()+':'+r.failure().errorText));
 await page.route('**/assets/.env',route=>route.fulfill({contentType:'text/plain',body:'API_BASE_URL=http://127.0.0.1:8089/api/v1\nE2E_MODE=true\nGOOGLE_API_KEY=\nSTRIPE_PUBLISHABLE_KEY=\nSENTRY_DSN=\n'}));
 await page.route('**/i.pravatar.cc/**',r=>r.fulfill({contentType:'image/png',body:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a4CYAAAAASUVORK5CYII=','base64')}));
 await page.goto('http://localhost:3000');
 await page.waitForTimeout(10000);
 await page.locator('flt-semantics-placeholder').evaluate(el=>el.click()).catch(()=>{});
 await page.waitForTimeout(500);
 console.log('WELCOME',await page.locator('body').innerText());
 await page.screenshot({path:shotDir+'/ux-welcome.png'});
 await page.getByText('Começar',{exact:true}).click();
 await page.waitForTimeout(1500);
 await page.locator('input').fill('e2e.cliente@nhac.local');
 await page.getByRole('button',{name:'Continuar',exact:true}).click();
 await page.waitForTimeout(1800);
 await page.locator('input').fill('NhacE2E#123');
 await page.getByRole('button',{name:'Continuar',exact:true}).click({timeout:5000});
 await page.waitForTimeout(3500);
 await page.screenshot({path:shotDir+'/home.png'});

 let countFail=true; let countCalls=0; let followCalls=0; let storeFail=true; let storeCalls=0;
 await page.route('**/favoritos/lojas/e2e-loja-001/contagem',async route=>{
   countCalls++;
   await route.fulfill({status:countFail?503:200,contentType:'application/json',body:countFail?JSON.stringify({message:'Falha simulada'}):'10'});
 });
 await page.route('**/usuarios/*/seguindo/e2e-loja-001',route=>route.fulfill({status:200,contentType:'application/json',body:'false'}));
 await page.route('**/api/v1/favoritos',async route=>{
   if(route.request().method()==='POST') {
     followCalls++;
     await new Promise(r=>setTimeout(r,1500));
     return route.fulfill({status:201,contentType:'application/json',body:'{}'});
   }
   await route.continue();
 });
 await page.route('**/api/v1/lojas/e2e-loja-001',async route=>{
   storeCalls++;
   if(storeFail)return route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({message:'Falha simulada'})});
   await route.continue();
 });
 await page.mouse.move(195,400); await page.mouse.wheel(0,1400); await page.waitForTimeout(600);
 await page.getByText('Loja E2E',{exact:false}).first().click();
 await page.getByText('Seguidores indisponíveis',{exact:true}).waitFor();
 await page.screenshot({path:shotDir+'/followers-failure.png'});
 countFail=false;
 await page.getByRole('button',{name:'Tentar novamente',exact:true}).click();
 await page.getByText('10 seguidores',{exact:true}).waitFor();
 const follow=page.getByRole('button',{name:'Seguir',exact:true});
 const box=await follow.boundingBox();
 await follow.click();
 for(let i=0;i<5;i++)await page.mouse.click(box.x+box.width/2,box.y+box.height/2);
 await page.getByRole('button',{name:'Seguindo',exact:true}).waitFor();
 if(followCalls!==1)throw Error('Operações repetidas: '+followCalls);
 await page.getByText('11 seguidores',{exact:true}).waitFor();
 await page.screenshot({path:shotDir+'/followers-success.png'});
 console.log(JSON.stringify({countCalls,followCalls,followerRetry:true,duplicateFollowBlocked:true}));
 await page.mouse.click(90,500);
 await page.waitForTimeout(800); console.log('PRODUCT',await page.locator('body').innerText());
 await page.getByRole('button',{name:'Loja indisponível. Tentar novamente',exact:true}).waitFor();
 if(await page.getByText('Loja fechada',{exact:true}).count())throw Error('Falha foi apresentada como fechada');
 await page.screenshot({path:shotDir+'/product-store-failure.png'});
 storeFail=false;
 await page.getByRole('button',{name:'Loja indisponível. Tentar novamente',exact:true}).focus();
 await page.keyboard.press('Enter');
 await page.getByRole('button',{name:/Adicionar/}).waitFor();
 await page.screenshot({path:shotDir+'/product-store-success.png'});
 console.log(JSON.stringify({countCalls,followCalls,storeCalls,followerRetry:true,duplicateFollowBlocked:true,storeFailureRecovered:true,errors}));
 await browser.close();
})().catch(async e=>{console.error(e);if(browser)await browser.close();process.exitCode=1;});
