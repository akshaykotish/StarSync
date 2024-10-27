import 'package:flutter/material.dart';


class Asrologerbranding extends StatefulWidget {
  const Asrologerbranding({super.key});

  @override
  State<Asrologerbranding> createState() => _AsrologerbrandingState();
}

class _AsrologerbrandingState extends State<Asrologerbranding> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 40,
            left: 20,
            right: 20,
            bottom: 20
          ),
          color: Color(0xFF778EFF), //#778EFF
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: (){Navigator.pop(context);},
                child: Container(
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back),
                      SizedBox(width: 5,),
                      Text("Back to Chat")
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20,),
              Container(
                width: MediaQuery.of(context).size.width - 40,
                child: Image.asset("assets/banner.png"),
              ),
              SizedBox(height: 5,),
              Container(
                  alignment: Alignment.center,
                  child: Text("From Ashish Moudgil's office and team", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),))
            ],
          ),
        ),
      ),
    );
  }
}
