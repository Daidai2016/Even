#target photoshop

app.bringToFront();


// =================================
// 大画面输出助手 V17
//
// Photoshop 27.10兼容
//
// 图像尺寸放大10倍输出
//
// 功能：
// ppi ÷10
// 保持像素
// TIFF LZW
// 自动归档
// 客户版输出报告
//
// 作者：Huaping Woo
// 联系：huaping.woo@gmail.com
//
// 不修改：
// CMYK
// ICC
// 像素
// =================================



// 文件名解码

function decodeFileName(name){

    try{

        return decodeURIComponent(name);

    }

    catch(e){

        return name;

    }

}



// 读取ICC

function getICCProfile(){

    try{


        var ref =
        new ActionReference();



        ref.putProperty(
            charIDToTypeID("Prpr"),
            stringIDToTypeID("profile")
        );



        ref.putEnumerated(
            charIDToTypeID("Dcmn"),
            charIDToTypeID("Ordn"),
            charIDToTypeID("Trgt")
        );



        var desc =
        executeActionGet(ref);



        if(
            desc.hasKey(
                stringIDToTypeID("profile")
            )
        ){

            return desc.getString(
                stringIDToTypeID("profile")
            );

        }


        return "未嵌入ICC";


    }

    catch(e){

        return "ICC读取失败";

    }

}



// 中国时间

function getChinaTime(){


    var now =
    new Date();



    function zero(n){

        return n < 10 ?
        "0"+n :
        n;

    }



    return (

        now.getFullYear()+
        "年"+
        zero(now.getMonth()+1)+
        "月"+
        zero(now.getDate())+
        "日 "+
        zero(now.getHours())+
        ":"+
        zero(now.getMinutes())+
        ":"+
        zero(now.getSeconds())

    );

}



// 判断方向

function getOrientation(w,h){


    if(w>h){

        return "横版";

    }


    if(w<h){

        return "竖版";

    }


    return "正方形";

}



// ===============================
// 文件检查
// ===============================


if(app.documents.length===0){


    alert(
        "没有打开文件。\n\n"+
        "请打开AI导出的TIFF文件。"
    );


    exit();

}



var activeDoc =
app.activeDocument;



// ===============================
// 读取信息
// ===============================


var sourcePPI =
activeDoc.resolution;



var sourceWidthCM =
activeDoc.width.as("cm");


var sourceHeightCM =
activeDoc.height.as("cm");



var outputPPI =
sourcePPI / 10;



var finalWidthCM =
sourceWidthCM * 10;


var finalHeightCM =
sourceHeightCM * 10;



var orientation =
getOrientation(
    finalWidthCM,
    finalHeightCM
);



var colorMode =
"未知";



switch(activeDoc.mode){


case DocumentMode.CMYK:

    colorMode="CMYK";

    break;



case DocumentMode.RGB:

    colorMode="RGB";

    break;



case DocumentMode.LAB:

    colorMode="Lab";

    break;



case DocumentMode.GRAYSCALE:

    colorMode="灰度";

    break;


}



var iccProfile =
getICCProfile();




// ===============================
// 安全检查
// ===============================


if(sourcePPI < 100){


    var lowConfirm =
    confirm(

        "当前文件分辨率较低：\n\n"+
        sourcePPI+
        " ppi\n\n"+
        "请确认是否为1:10制作文件。\n\n"+
        "是否继续？"

    );


    if(!lowConfirm){

        exit();

    }

}



// ===============================
// 输出预览
// ===============================


var preview =
new Window(
    "dialog"
    ,
    "输出确认"
);



preview.orientation =
"column";



var previewText =


"========================\n"+
"输出确认\n"+
"========================\n\n"+


"文件：\n"+
decodeFileName(activeDoc.name)+
"\n\n"+


"原始尺寸：\n"+
sourceWidthCM.toFixed(1)+
" × "+
sourceHeightCM.toFixed(1)+
" cm\n\n"+


"成品尺寸：\n"+
finalWidthCM.toFixed(1)+
" × "+
finalHeightCM.toFixed(1)+
" cm\n\n"+


"方向："+
orientation+
"\n\n"+


"制作DPI："+
Math.round(outputPPI)+
"\n\n"+


"色彩模式："+
colorMode+
"\n\n"+


"ICC：\n"+
iccProfile+
"\n\n"+


"格式：TIFF LZW";



preview.add(
    "statictext",
    undefined,
    previewText,
    {
        multiline:true
    }
);

preview.add(
    "statictext",
    undefined,
    ""
);


// 作者信息

// ===============================
// 作者信息（右下角灰色小字）
// ===============================


var bottomGroup =
preview.add(
    "group"
);


bottomGroup.alignment =
"right";



var authorText =
bottomGroup.add(
    "statictext",
    undefined,
    "by Huaping Woo"
);



// 设置灰色文字

authorText.graphics.foregroundColor =
authorText.graphics.newPen(
    authorText.graphics.PenType.SOLID_COLOR,
    [0.45,0.45,0.45,1],
    1
);



// 小字号

authorText.graphics.font =
ScriptUI.newFont(
    "Arial",
    "regular",
    10
);


var btn =
preview.add("group");



var ok =
btn.add(
    "button",
    undefined,
    "确认输出"
);



var cancel =
btn.add(
    "button",
    undefined,
    "取消"
);



var run=false;



ok.onClick=function(){

    run=true;

    preview.close();

};



cancel.onClick=function(){

    preview.close();

};



preview.show();



if(!run){

    exit();

}



// ===============================
// 修改ppi
// 保持像素
// ===============================


activeDoc.resizeImage(

    undefined,
    undefined,
    outputPPI,
    ResampleMethod.NONE

);



// ===============================
// 创建文件夹
// ===============================


var sourceFile =
activeDoc.fullName;



var parentFolder =
sourceFile.parent;



var projectName =
decodeFileName(

    sourceFile.name.replace(
        /\.[^\.]+$/,
        ""
    )

);



var outputFolder =
new Folder(

    parentFolder+
    "/"+
    projectName+
    "_制作文件"

);



if(!outputFolder.exists){

    outputFolder.create();

}



// ===============================
// 保存TIFF
// ===============================


var outputFile =
new File(

    outputFolder+
    "/"+
    projectName+
    "_定稿.tif"

);



var tiffOptions =
new TiffSaveOptions();



tiffOptions.imageCompression =
TIFFEncoding.TIFFLZW;



tiffOptions.embedColorProfile =
true;



activeDoc.saveAs(

    outputFile,

    tiffOptions,

    true,

    Extension.LOWERCASE

);



// ===============================
// TXT报告
// ===============================


var reportFile =
new File(

    outputFolder+
    "/"+
    projectName+
    "_输出报告.txt"

);



reportFile.encoding =
"UTF-8";


reportFile.open("w");



reportFile.write("\uFEFF");



reportFile.write(


"========================\n"+
"  输出报告\n"+
"========================\n\n"+


"  项目名称：\n"+
"  "+
projectName+
"\n\n"+


"  时间：\n"+
"  "+
getChinaTime()+
"\n\n"+


"  尺寸：\n"+
"  "+
finalWidthCM.toFixed(1)+
" × "+
finalHeightCM.toFixed(1)+
" cm\n\n"+


"  方向：\n"+
"  "+
orientation+
"\n\n"+


"  制作DPI：\n"+
"  "+
Math.round(outputPPI)+
"\n\n"+


"  色彩模式：\n"+
"  "+
colorMode+
"\n\n"+


"  ICC：\n"+
"  "+
iccProfile+
"\n\n"+


"  输出文件：\n"+
"  "+
projectName+
"_定稿.tif\n\n"+


"========================\n"+
"  联系作者：\n"+
"  huaping.woo@gmail.com"


);



reportFile.close();


// ===============================
// 完成
// ===============================