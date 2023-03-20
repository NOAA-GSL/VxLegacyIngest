import lib.*;
import sdg.*;
import java.util.*;
import java.io.*;

public class Test {

public static void main(String args[]) {
  float z =MyUtil.atoi(args[0]);
  double p1 = Sounding.getStdPressure(z/0.3048); // wants z in ft
  double p2 = ztopsa(z);
  System.out.println("p1 "+p1+"\np2 "+p2);
}

public static double ztopsa(double z) {
  double p0 = 1013.2;
  double gamma = 0.0065;
  double t0 = 288.;
  double c1 = 5.256;
  double ztopsa = p0 * Math.pow((t0 - gamma*z)/t0,c1);
  return ztopsa;
}
}
