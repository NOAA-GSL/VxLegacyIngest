import lib.*;

 public class BiasData {
   int xid;
   int secs;
   int mb;
   double t_omb;
   int N;

public BiasData(int xid,int secs,int mb,double t_omb,int N) {
  this.xid = xid;
  this.secs = secs;
  this.mb = mb;
  this.t_omb = t_omb;
  this.N = N;
}

public String toString() {
  return ""+xid+", "+secs+", "+mb+", "+t_omb+", "+N;
}
}
     
