library open_ai_robot_helper;
import 'package:open_ai_robot_helper/open_ai/open_ai_main.dart';

class OpenAiRobotHelper {
  late OpenAIMain openAIMain;

  Future<void> init(String appKey, String orgID) async {
    openAIMain = OpenAIMain();
    await openAIMain.initOpenAIClient(appKey, orgID);
  }
  //Stream<String> listeningResult get ;
}
