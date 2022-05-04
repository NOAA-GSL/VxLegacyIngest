package lib;

import java.awt.*;

public final class DefaultColors {
private static Color[] color = new Color[64];
private static boolean colors_set = false;

public static Color[] get_colors() {
  if(!colors_set) {
  color[0] = new Color(0,0,0);
  color[1] = new Color(0,0,143);
  color[2] = new Color(0,0,159);
  color[3] = new Color(0,0,175);
  color[4] = new Color(0,0,191);
  color[5] = new Color(0,0,207);
  color[6] = new Color(0,0,223);
  color[7] = new Color(0,0,239);
  color[8] = new Color(0,0,255);
  color[9] = new Color(0,11,255);
  color[10] = new Color(0,27,255);
  color[11] = new Color(0,43,255);
  color[12] = new Color(0,59,255);
  color[13] = new Color(0,75,255);
  color[14] = new Color(0,91,255);
  color[15] = new Color(0,107,255);
  color[16] = new Color(0,123,255);
  color[17] = new Color(0,139,255);
  color[18] = new Color(0,155,255);
  color[19] = new Color(0,171,255);
  color[20] = new Color(0,187,255);
  color[21] = new Color(0,203,255);
  color[22] = new Color(0,219,255);
  color[23] = new Color(0,235,255);
  color[24] = new Color(0,251,255);
  color[25] = new Color(7,255,247);
  color[26] = new Color(23,255,231);
  color[27] = new Color(39,255,215);
  color[28] = new Color(55,255,199);
  color[29] = new Color(71,255,183);
  color[30] = new Color(87,255,167);
  color[31] = new Color(103,255,151);
  color[32] = new Color(119,255,135);
  color[33] = new Color(135,255,119);
  color[34] = new Color(151,255,103);
  color[35] = new Color(167,255,87);
  color[36] = new Color(183,255,71);
  color[37] = new Color(199,255,55);
  color[38] = new Color(215,255,39);
  color[39] = new Color(231,255,23);
  color[40] = new Color(247,255,7);
  color[41] = new Color(255,247,0);
  color[42] = new Color(255,231,0);
  color[43] = new Color(255,215,0);
  color[44] = new Color(255,199,0);
  color[45] = new Color(255,183,0);
  color[46] = new Color(255,167,0);
  color[47] = new Color(255,151,0);
  color[48] = new Color(255,135,0);
  color[49] = new Color(255,119,0);
  color[50] = new Color(255,103,0);
  color[51] = new Color(255,87,0);
  color[52] = new Color(255,71,0);
  color[53] = new Color(255,55,0);
  color[54] = new Color(255,39,0);
  color[55] = new Color(255,23,0);
  color[56] = new Color(255,7,0);
  color[57] = new Color(246,0,0);
  color[58] = new Color(228,0,0);
  color[59] = new Color(211,0,0);
  color[60] = new Color(193,0,0);
  color[61] = new Color(175,0,0);
  color[62] = new Color(158,0,0);
  color[63] = new Color(140,0,0);
  colors_set = true;
  }
  return color;
}
}
