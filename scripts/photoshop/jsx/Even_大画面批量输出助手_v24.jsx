#target photoshop


app.bringToFront();



// ==================================================
// 大画面输出助手 V20.3.2
//
// Photoshop 27.10
//
// 更新：
// 1. Photoshop错误静默
// 2. 损坏文件自动跳过
// 3. 错误日志去重
// 4. 批处理不中断
//
// ==================================================




// ==================================================
// 全局变量
// ==================================================


var errorList = [];

var lowPPIList = [];

var reportData = [];

var commonICC = "";

var commonDPI = "";

var startTime = "";

var endTime = "";

var lastFinishTime = "";







// ==================================================
// 错误日志去重
// ==================================================


function addError(msg){


    for(
        var i=0;
        i<errorList.length;
        i++
    ){


        if(
            errorList[i] == msg
        ){

            return;

        }


    }



    errorList.push(msg);


}







// ==================================================
// 中文文件名读取
// ==================================================

function decodeFileName(file){


    try{


        return decodeURIComponent(
            file.name
        );


    }
    catch(e){


        return file.name;


    }


}







// ==================================================
// UTF-8 TXT写入
// ==================================================

function writeUTF8(file,text){


    file.encoding =
    "UTF-8";


    file.open("w");


    file.write(
        "\uFEFF"+
        text
    );


    file.close();


}







// ==================================================
// 中国时间
// ==================================================

function getChinaTime(){


    var d =
    new Date();



    function zero(n){


        return n<10 ?
        "0"+n :
        n;


    }



    return (

        d.getFullYear()
        +"年"
        +
        zero(
            d.getMonth()+1
        )
        +"月"
        +
        zero(
            d.getDate()
        )
        +"日 "
        +
        zero(
            d.getHours()
        )
        +":"
        +
        zero(
            d.getMinutes()
        )
        +":"
        +
        zero(
            d.getSeconds()
        )

    );


}








// ==================================================
// 脚本提醒
// ==================================================

function showMessage(msg){



    var win =
    new Window(
        "dialog",
        "脚本提醒"
    );



    win.orientation =
    "column";



    var text =
    win.add(
        "statictext",
        undefined,
        msg,
        {
            multiline:true
        }
    );



    text.preferredSize.width =
    420;



    var btn =
    win.add(
        "button",
        undefined,
        "确定"
    );



    btn.onClick=function(){


        win.close();


    };



    win.show();


}








// ==================================================
// Photoshop错误静默控制
// ==================================================

function setSilentMode(){


    app.displayDialogs =
    DialogModes.NO;


}






function restoreDialogMode(mode){


    app.displayDialogs =
    mode;


}








// ==================================================
// 安全关闭已有文件
// ==================================================

function safeCloseDocuments(){



    while(
        app.documents.length>0
    ){


        var doc =
        app.activeDocument;



        if(
            doc.saved
        ){


            doc.close(
                SaveOptions.DONOTSAVECHANGES
            );


        }
        else{


            var r =
            askSaveDocument(
                doc.name
            );



            if(
                r=="save"
            ){


                doc.save();


                doc.close(
                    SaveOptions.SAVECHANGES
                );


            }
            else if(
                r=="discard"
            ){


                doc.close(
                    SaveOptions.DONOTSAVECHANGES
                );


            }
            else{


                exit();


            }


        }


    }


}







// ==================================================
// 未保存文件处理
// ==================================================

function askSaveDocument(name){



    var win =
    new Window(
        "dialog",
        "脚本提醒"
    );



    win.orientation =
    "column";



    win.add(
        "statictext",
        undefined,
        "发现未保存文件：\n\n"+
        name+
        "\n\n请选择处理方式。",
        {
            multiline:true
        }
    );



    var group =
    win.add(
        "group"
    );



    var result =
    "cancel";



    var save =
    group.add(
        "button",
        undefined,
        "保存并关闭"
    );



    var discard =
    group.add(
        "button",
        undefined,
        "不保存关闭"
    );



    var cancel =
    group.add(
        "button",
        undefined,
        "取消"
    );



    save.onClick=function(){

        result="save";
        win.close();

    };



    discard.onClick=function(){

        result="discard";
        win.close();

    };



    cancel.onClick=function(){

        result="cancel";
        win.close();

    };



    win.show();



    return result;


}








// ==================================================
// 选择文件夹
// ==================================================

function selectFolder(title){


    var folder =
    Folder.selectDialog(
        title
    );



    if(
        folder==null
    ){


        exit();


    }



    return folder;


}







// ==================================================
// 获取TIFF
// ==================================================

function getTiffFiles(folder){


    return folder.getFiles(

        function(f){


            if(
                f instanceof File
            ){


                var n =
                f.name.toLowerCase();



                return (

                    n.indexOf(".tif")!=-1

                );


            }



            return false;


        }

    );


}







// ==================================================
// 项目名称
// ==================================================

function getProjectName(file){


    var name =
    decodeFileName(file);



    return name.replace(
        /\.[^\.]+$/,
        ""
    );


}
// ==================================================
// 获取ICC
// ==================================================

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






// ==================================================
// DPI
// ==================================================

function getOutputDPI(ppi){


    return Math.round(
        ppi/10
    );


}






// ==================================================
// 横竖版
// ==================================================

function getOrientation(w,h){


    if(w>h){

        return "横版";

    }


    if(w<h){

        return "竖版";

    }


    return "正方形";


}







// ==================================================
// cm格式
// ==================================================

function formatCM(value){


    return value.toFixed(1);


}






// ==================================================
// 版本文件
// ==================================================

function getVersionFile(file){


    var folder =
    file.parent;


    var name =
    file.name.replace(
        /\.tif$/i,
        ""
    );



    var num = 2;


    var newFile;



    do{


        newFile =
        new File(

            folder+
            "/"+
            name+
            "_v0"+
            num+
            ".tif"

        );



        num++;



    }
    while(
        newFile.exists
    );



    return newFile;


}







// ==================================================
// 状态栏
// ==================================================

function updateProgress(current,total,name){


    try{


        app.updateProgress(
            current,
            total
        );



        app.updateStatusBarMessage(

            "正在处理："+
            current+
            " / "+
            total+
            "\n"+
            name

        );


    }
    catch(e){


    }


}







// ==================================================
// 桌面日志
// ==================================================

function getDesktopLogFile(folderName){


    return new File(

        Folder.desktop+
        "/"+
        folderName+
        "_运行日志.txt"

    );


}







// ==================================================
// 文件冲突检查
// ==================================================

function checkExistingFile(file){


    if(
        !file.exists
    ){


        return file;


    }



    return getVersionFile(file);


}







// ==================================================
// 主程序开始
// ==================================================


safeCloseDocuments();



startTime =
getChinaTime();




// 输入文件夹

var inputFolder =
selectFolder(
    "请选择需要处理的文件夹"
);



var inputFolderName =
inputFolder.name;




var files =
getTiffFiles(
    inputFolder
);




if(
    files.length===0
){


    showMessage(
        "没有找到TIFF文件"
    );


    exit();


}






// 输出位置

var outputParent =
selectFolder(
    "请选择输出位置"
);






// 输出文件夹

var outputFolder =
new Folder(

    outputParent+
    "/"+
    inputFolderName+
    "_制作文件"

);




if(
    !outputFolder.exists
){

    outputFolder.create();

}








// ==================================================
// 第一轮扫描
// ==================================================


var iccList=[];

var dpiList=[];



for(
    var i=0;
    i<files.length;
    i++
){



    var oldDialog =
    app.displayDialogs;



    setSilentMode();



    try{


        var checkDoc =
        app.open(
            files[i]
        );



        if(
            checkDoc.mode != DocumentMode.CMYK
        ){


            addError(

                decodeFileName(files[i])
                +
                "\n原因：颜色模式不是CMYK"

            );


        }






        iccList.push(

            getICCProfile()

        );



        dpiList.push(

            getOutputDPI(
                checkDoc.resolution
            )

        );





        checkDoc.close(
            SaveOptions.DONOTSAVECHANGES
        );



    }
    catch(e){



        addError(

            decodeFileName(files[i])
            +
            "\n原因：文件无法打开"

        );



    }



    restoreDialogMode(
        oldDialog
    );



}







// ==================================================
// ICC统一检测
// ==================================================

if(
    iccList.length>0
){

    commonICC =
    iccList[0];



    for(
        var ic=0;
        ic<iccList.length;
        ic++
    ){


        if(
            iccList[ic]!=commonICC
        ){


            addError(
                "原因：ICC配置不统一"
            );


            break;


        }


    }


}








// ==================================================
// DPI统一检测
// ==================================================

if(
    dpiList.length>0
){

    commonDPI =
    dpiList[0];



    for(
        var dp=0;
        dp<dpiList.length;
        dp++
    ){


        if(
            dpiList[dp]!=commonDPI
        ){


            addError(
                "原因：制作DPI不统一"
            );


            break;


        }


    }


}








// ==================================================
// 第二轮输出
// ==================================================

for(
    var j=0;
    j<files.length;
    j++
){


    updateProgress(

        j+1,

        files.length,

        decodeFileName(
            files[j]
        )

    );



    var oldMode =
    app.displayDialogs;



    setSilentMode();



    try{


        var doc =
        app.open(
            files[j]
        );



        var sourcePPI =
        doc.resolution;



        if(
            sourcePPI<100
        ){


            lowPPIList.push(

                decodeFileName(files[j])
                +
                "\n原始ppi："
                +
                sourcePPI

            );


        }







        var widthCM =
        doc.width.as("cm");



        var heightCM =
        doc.height.as("cm");



        var finalWidth =
        widthCM*10;



        var finalHeight =
        heightCM*10;





        var outputDPI =
        getOutputDPI(
            sourcePPI
        );





        var orientation =
        getOrientation(

            finalWidth,

            finalHeight

        );






        // 修改ppi
        // 不改变像素


        doc.resizeImage(

            undefined,

            undefined,

            outputDPI,

            ResampleMethod.NONE

        );








        var projectName =
        getProjectName(
            files[j]
        );





        var saveFile =
        new File(

            outputFolder+
            "/"+
            projectName+
            "_定稿.tif"

        );



        saveFile =
        checkExistingFile(
            saveFile
        );





        var options =
        new TiffSaveOptions();



        options.imageCompression =
        TIFFEncoding.TIFFLZW;



        options.embedColorProfile =
        true;





        doc.saveAs(

            saveFile,

            options,

            true,

            Extension.LOWERCASE

        );






        reportData.push({

            name:
            projectName,


            width:
            formatCM(finalWidth),


            height:
            formatCM(finalHeight),


            orientation:
            orientation,


            dpi:
            outputDPI,


            file:
            decodeFileName(saveFile)

        });







        doc.close(
            SaveOptions.DONOTSAVECHANGES
        );




    }
    catch(e){



        addError(

            decodeFileName(files[j])
            +
            "\n原因：输出失败"

        );



        try{


            if(
                app.documents.length>0
            ){

                app.activeDocument.close(
                    SaveOptions.DONOTSAVECHANGES
                );


            }


        }
        catch(closeError){}



    }



    restoreDialogMode(
        oldMode
    );



}
// ==================================================
// 完稿时间
// ==================================================

endTime =
getChinaTime();


lastFinishTime =
endTime;






// ==================================================
// 客户输出报告
// ==================================================

var reportFile =
new File(

    outputFolder+
    "/"+
    inputFolderName+
    "_输出报告.txt"

);





var reportText = "";





reportText +=

"========================\n"+
"  输出报告\n"+
"========================\n\n";






// 完稿时间

reportText +=

"  完稿时间：\n"+
"  "+
lastFinishTime+
"\n\n";






// 文件数量

reportText +=

"  文件数量：\n"+
"  "+
reportData.length+
"\n\n";







// 文件名称及尺寸

reportText +=

"  文件名称及尺寸：\n";




for(
    var i=0;
    i<reportData.length;
    i++
){



    reportText +=


    "\n"+
    "  "+
    reportData[i].name+
    "\n"+
    "  "+
    reportData[i].width+
    " × "+
    reportData[i].height+
    " cm\n";



}







// 制作DPI

reportText +=


"\n"+
"  制作DPI：\n"+
"  "+
Math.round(commonDPI)+
"\n\n";








// 色彩模式

reportText +=


"  色彩模式：\n"+
"  CMYK\n\n";







// ICC

reportText +=


"  ICC：\n"+
"  "+
commonICC+
"\n\n";







// 输出文件

reportText +=


"  输出文件：\n";




for(
    var o=0;
    o<reportData.length;
    o++
){


    reportText +=


    "\n"+
    "  "+
    reportData[o].file+
    "\n";


}








// ==================================================
// 错误日志
// 有错误才显示
// ==================================================

if(
    errorList.length>0
){



    reportText +=


    "\n"+
    "  错误日志：\n";



    for(
        var e=0;
        e<errorList.length;
        e++
    ){


        reportText +=


        "\n"+
        "  "+
        errorList[e]+
        "\n";


    }



}








// ==================================================
// 低PPI提醒
// ==================================================

if(
    lowPPIList.length>0
){


    reportText +=


    "\n"+
    "  低PPI提醒：\n";



    for(
        var l=0;
        l<lowPPIList.length;
        l++
    ){


        reportText +=


        "\n"+
        "  "+
        lowPPIList[l]+
        "\n";


    }


}






// 写入客户报告

writeUTF8(

    reportFile,

    reportText

);










// ==================================================
// 桌面运行日志
// ==================================================

var logFile =
getDesktopLogFile(
    inputFolderName
);




var logText = "";




logText +=


"========================\n"+
"运行日志\n"+
"========================\n\n";







logText +=


"开始时间：\n"+
"  "+
startTime+
"\n\n";







logText +=


"结束时间：\n"+
"  "+
endTime+
"\n\n";







logText +=


"扫描文件数量：\n"+
"  "+
files.length+
"\n\n";







logText +=


"成功输出数量：\n"+
"  "+
reportData.length+
"\n\n";







// 错误

if(
    errorList.length>0
){


    logText +=


    "错误数量：\n"+
    "  "+
    errorList.length+
    "\n\n";



    logText +=


    "错误内容：\n";



    for(
        var x=0;
        x<errorList.length;
        x++
    ){


        logText +=


        "\n"+
        "  "+
        errorList[x]+
        "\n";


    }



}
else{


    logText +=


    "错误：\n"+
    "  无\n";


}






writeUTF8(

    logFile,

    logText

);








// ==================================================
// 清除状态栏
// ==================================================

try{


    app.updateStatusBarMessage(
        "批处理完成"
    );


}
catch(e){}






// ==================================================
// 最终提醒
// ==================================================

showMessage(

"批处理完成！\n\n"+
"成功输出："+
reportData.length+
" 个文件\n\n"+
"输出文件夹：\n"+
outputFolder.fsName+
"\n\n"+
"运行日志：\n"+
logFile.fsName

);