package com.neaserisgod.mireparto;

import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.security.MessageDigest;
import java.util.HashMap;

public class MainActivity extends FlutterActivity {
  @Override public void configureFlutterEngine(@NonNull FlutterEngine engine) {
    super.configureFlutterEngine(engine);
    if ((getApplicationInfo().flags & android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
      try { Class.forName("org.maplibre.android.log.Logger").getMethod("setVerbosity", int.class).invoke(null, android.util.Log.DEBUG); }
      catch (Exception ignored) { }
    }
    new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), "app.personal/actualizaciones").setMethodCallHandler((call,result) -> {
      try {
        if (call.method.equals("info")) {
          PackageInfo info=getPackageManager().getPackageInfo(getPackageName(),0);
          HashMap<String,Object> data=new HashMap<>();
          data.put("version",info.versionName);data.put("build",Build.VERSION.SDK_INT>=28?info.getLongVersionCode():(long)info.versionCode);data.put("package",getPackageName());result.success(data);
        } else if (call.method.equals("pantallaNavegacion")) {
          if(Boolean.TRUE.equals(call.argument("activa"))) getWindow().addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
          else getWindow().clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
          result.success(null);
        } else if (call.method.equals("instalar")) {
          String path=call.argument("path");if(path==null)throw new IllegalArgumentException("Archivo inválido.");
          File file=new File(path).getCanonicalFile(),dir=new File(getCacheDir(),"updates").getCanonicalFile();
          if(!file.getPath().startsWith(dir.getPath()+File.separator)||!file.isFile())throw new IllegalArgumentException("Archivo de actualización inválido.");
          int flags=Build.VERSION.SDK_INT>=28?PackageManager.GET_SIGNING_CERTIFICATES:PackageManager.GET_SIGNATURES;
          PackageInfo apk=getPackageManager().getPackageArchiveInfo(file.getPath(),flags),installed=getPackageManager().getPackageInfo(getPackageName(),flags);
          if(apk==null||!getPackageName().equals(apk.packageName))throw new IllegalArgumentException("El APK no corresponde a esta app.");
          long next=Build.VERSION.SDK_INT>=28?apk.getLongVersionCode():apk.versionCode,current=Build.VERSION.SDK_INT>=28?installed.getLongVersionCode():installed.versionCode;
          if(next<=current)throw new IllegalArgumentException("Esta versión ya está instalada o es anterior.");
          Signature[] a=Build.VERSION.SDK_INT>=28?apk.signingInfo.getApkContentsSigners():apk.signatures,b=Build.VERSION.SDK_INT>=28?installed.signingInfo.getApkContentsSigners():installed.signatures;
          if(a.length!=1||b.length!=1||!MessageDigest.isEqual(a[0].toByteArray(),b[0].toByteArray()))throw new IllegalArgumentException("La firma no coincide. Conservá un respaldo antes de cambiar de instalación.");
          if(Build.VERSION.SDK_INT>=26&&!getPackageManager().canRequestPackageInstalls()) {
            startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,Uri.parse("package:"+getPackageName())));result.success("permiso");return;
          }
          Uri uri=FileProvider.getUriForFile(this,getPackageName()+".actualizaciones",file);
          startActivity(new Intent(Intent.ACTION_VIEW).setDataAndType(uri,"application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_ACTIVITY_NEW_TASK));result.success("instalador");
        } else {result.notImplemented();}
      }catch(Exception e){result.error("actualizacion",e.getMessage(),null);}
    });
  }
}
