const fs=require('fs'), path=require('path');
const root=path.resolve(__dirname,'..'), src=path.join(root,'web'), out=path.join(root,'dist');
fs.rmSync(out,{recursive:true,force:true}); fs.cpSync(src,out,{recursive:true});
const cfg=`window.AURA_CONFIG = ${JSON.stringify({familyId:process.env.AURA_FAMILY_ID||'',apiUrl:process.env.AURA_API_URL||'',localDevToken:process.env.AURA_LOCAL_DEV_TOKEN||''},null,2)};\n`;
fs.writeFileSync(path.join(out,'js','aura-config.js'),cfg);
console.log('Aura v2 build complete -> dist');
console.log('Family configured:',!!process.env.AURA_FAMILY_ID,'API configured:',!!process.env.AURA_API_URL);
