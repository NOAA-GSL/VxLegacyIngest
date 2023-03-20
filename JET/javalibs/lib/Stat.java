package lib;

public final class Stat {
  
public static double[] getStdErr(double[] data) {

  int n = data.length;
  double sum=0;
  double sum2=0;
  int n_good = 0;
  for(int i=0;i<n;i++) {
    if(!Double.isNaN(data[i])) {
      n_good++;
      sum += data[i];
      sum2 += data[i]*data[i];
    }
  }
  double mean = sum/n_good;
  double sd = Math.sqrt(sum2/n_good - mean*mean);

  // get autocorrelation for each lag
  double[] r = new double[data.length];
  double r_sum=0;
  double rfact=0;
  int count=0;
  // from http://www.itl.nist.gov/div898/handbook/eda/section3/eda35c.htm
  for(int lag=1;lag<n;lag++) {
    r[lag] = 0;
    int n_in_lag=0;
    for(int t=0;t<n-lag;t++) {
      if(!Double.isNaN(data[t]) &&
	 !Double.isNaN(data[t+lag])) {
	r[lag] += (data[t]-mean)*(data[t+lag]-mean);
	n_in_lag++;
      }
    }
    r[lag] /= n_in_lag*sd*sd;
    r_sum += r[lag];
    // from http://en.wikipedia.org/wiki/Unbiased_estimation_of_standard_deviation
    rfact += (1.0 - (lag+0.0)/n)*r[lag];
    count++;
    //Debug.println("r for lag "+lag+" is "+r[lag]);
  }

  // Betsy Weatherhead's correction, based on lag 1
  double stde_betsy = Double.NaN;
  if(n > 2) {
    double betsy = Math.sqrt((n-1)*(1. - r[1]));
    stde_betsy = sd/betsy;
  }
  
  // probably wrong to get average autocorrelation
  double r_avg = r_sum/count;
  //Debug.println("r_avg is "+r_avg);
  // from http://en.wikipedia.org/wiki/Unbiased_estimation_of_standard_deviation
  double fact2 = Math.sqrt(1 - 2*rfact/(n-1));
  //Debug.println("rfact is "+rfact+", fact2 is "+fact2);

  double f = Math.sqrt((1 + (n-1)*r_avg)/(1-r_avg));
  //Debug.println("f is "+f);

  // standard error
  double stde2 = sd*fact2/Math.sqrt(n);
  Debug.println("stde_betsy "+stde_betsy+", stde2 "+stde2+", sd "+sd+", n "+n_good+", r1 "+r[1]);
  double[] result = new double[5];
  result[0] = mean;
  result[1] = stde_betsy;
  result[2] = sd;
  result[3] = n_good;
  if(n > 2) {
    result[4] = r[1];
  } else {
    result[4] = Double.NaN;
  }
  return result;
}
  
public static void main(String[] args) {
  // test data from http://www.itl.nist.gov/div898/handbook/eda/section4/eda4251.htm
  // should yield an autocorrelation at lag 1 of -0.3073048E+00
  double[] data = {-213,-564, -35, -15, 141, 115,-420,-360, 203,-338,-431, 194,-220,-513,
		   154,-125,-559,92, -21,-579, -52,99,-543,-175, 162,-457,-346, 204,-300,
		   -474, 164,-107,-572,-8,83,-541,-224, 180,-420,-374, 201,-236,-531,83,
		   27,-564,-112, 131,-507,-254, 199,-311,-495, 143, -46,-579, -90, 136,-472,
		   -338, 202,-287,-477, 169,-124,-568,17,48,-568,-135, 162,-430,-422, 172,
		   -74,-577, -13,92,-534,-243, 194,-355,-465, 156, -81,-578, -64, 139,-449,
		   -384, 193,-198,-538, 110, -44,-577,-6,66,-552,-164, 161,-460,-344, 205,
		   -281,-504, 134, -28,-576,-118, 156,-437,-381, 200,-220,-540,83,11,-568,
		   -160, 172,-414,-408, 188,-125,-572, -32, 139,-492,-321, 205,-262,-504,
		   142, -83,-574, 0,48,-571,-106, 137,-501,-266, 190,-391,-406, 194,-186,
		   -553,83, -13,-577, -49, 103,-515,-280, 201, 300,-506, 131, -45,-578, -80,
		   138,-462,-361, 201,-211,-554,32,74,-533,-235, 187,-372,-442, 182,-147,
		   -566,25,68,-535,-244, 194,-351,-463, 174,-125,-570,15,72,-550,-190, 172,
		   -424,-385, 198,-218,-536,96};
  Debug.DEBUG = true;
  double[] result = Stat.getStdErr(data);
  Debug.println("mean is "+result[0]+", stde is "+result[1]+", sd is "+result[2]+
		", n is "+result[3]+", lag1 is "+result[4]);

}
}
    
  
  