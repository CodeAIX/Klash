package com.codeaix.klashiconlab;

import android.Manifest;
import android.app.*;
import android.os.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.*;
import android.graphics.drawable.Icon;
import android.view.*;
import android.widget.*;

public class MainActivity extends Activity {
  private static final String CHANNEL="icon_lab", TAG="icon_lab";
  private static final int NOTIFICATION=7104;
  private final String[] countries={"US","JP","HK","SG","DE","GB"};
  private int index=0, mode=2, variant=0;
  private boolean good=true;
  private TextView status;
  private NotificationManager manager;
  private final Handler handler=new Handler(Looper.getMainLooper());
  private boolean cycling=false;
  private final Runnable cycle=new Runnable(){public void run(){if(cycling){index=(index+1)%countries.length;showIcon();handler.postDelayed(this,3000);}}};
  @Override public void onCreate(Bundle b){
    super.onCreate(b);
    manager=getSystemService(NotificationManager.class);
    manager.createNotificationChannel(new NotificationChannel(CHANNEL,"Klash Icon Lab",NotificationManager.IMPORTANCE_LOW));
    LinearLayout root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setPadding(24,24,24,24);
    ScrollView scroll=new ScrollView(this);scroll.addView(root);setContentView(scroll);
    TextView title=new TextView(this);title.setText("Klash Icon Lab · HyperOS 4.0.6");title.setTextSize(22);root.addView(title);
    status=new TextView(this);status.setTextSize(16);root.addView(status);
    add(root,"A 标准单色",()->{variant=0;showIcon();});
    add(root,"B 彩色 Bitmap",()->{variant=1;showIcon();});
    add(root,"C 彩色资源风格（Bitmap 对照）",()->{variant=2;showIcon();});
    add(root,"切换国家",()->{index=(index+1)%countries.length;showIcon();});
    add(root,"切换模式：无 / 左点 / 右点 / 双点",()->{mode=(mode+1)%4;showIcon();});
    add(root,"切换 IP 优质下划线",()->{good=!good;showIcon();});
    add(root,"异常 !",()->{variant=3;showIcon();});
    add(root,"停止 II",()->{variant=4;showIcon();});
    add(root,"开始/停止 3 秒自动切换",()->{cycling=!cycling;handler.removeCallbacks(cycle);if(cycling)handler.post(cycle);});
    add(root,"清除测试通知",()->{cycling=false;handler.removeCallbacks(cycle);manager.cancel(NOTIFICATION);});
    if(Build.VERSION.SDK_INT>=33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},12);
    showIcon();
  }
  private void add(LinearLayout root,String label,Runnable action){Button b=new Button(this);b.setText(label);root.addView(b);b.setOnClickListener(v->action.run());}
  private Bitmap draw(boolean color){
    Bitmap bitmap=Bitmap.createBitmap(96,96,Bitmap.Config.ARGB_8888);
    Canvas c=new Canvas(bitmap);
    Paint p=new Paint(3);
    if(color){p.setColor(variant==2?Color.rgb(20,125,100):mode==2?Color.rgb(20,150,85):mode==1?Color.rgb(30,110,220):Color.rgb(225,135,30));c.drawRoundRect(0,4,96,92,18,18,p);}
    p.setColor(Color.WHITE);p.setTypeface(Typeface.create("sans-serif-condensed",Typeface.BOLD));p.setTextAlign(Paint.Align.CENTER);p.setTextSize(49);
    String code=variant==3?"!":variant==4?"II":countries[index];
    c.drawText(code,48,62,p);
    if(variant<3){
      if(mode==1||mode==3)c.drawCircle(8,46,5,p);
      if(mode==2||mode==3)c.drawCircle(88,46,5,p);
      if(good){p.setStrokeWidth(5);p.setStrokeCap(Paint.Cap.ROUND);c.drawLine(27,75,69,75,p);}
    }
    return bitmap;
  }
  private void showIcon(){
    boolean colored=variant==1||variant==2;
    Bitmap bmp=draw(colored);
    Icon icon=Icon.createWithBitmap(bmp);
    String details="国家 "+countries[index]+" · 模式 "+new String[]{"无","系统代理","TUN","双模式"}[mode]+" · IP优秀 "+good+" · 测试 "+variant;
    status.setText(details);
    Intent intent=new Intent(this,MainActivity.class);
    PendingIntent pi=PendingIntent.getActivity(this,0,intent,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
    Notification n=new Notification.Builder(this,CHANNEL).setSmallIcon(icon).setContentTitle("Klash Icon Lab").setContentText(details).setContentIntent(pi).setOngoing(true).setOnlyAlertOnce(true).build();
    try{manager.notify(NOTIFICATION,n);}catch(Exception e){status.setText(details+"\n通知失败："+e.getMessage());}
  }
  @Override public void onRequestPermissionsResult(int requestCode,String[] permissions,int[] results){super.onRequestPermissionsResult(requestCode,permissions,results);if(requestCode==12)showIcon();}
  @Override protected void onDestroy(){cycling=false;handler.removeCallbacks(cycle);super.onDestroy();}
}
