//@target photoshop


app.bringToFront();



// ==================================================
// 大画面批量输出助手 V28.0.0
//
// 兼容范围：
// 1. Adobe Photoshop 2022-2026（23.x-27.x）
// 2. Adobe Photoshop Beta
// 3. Windows 与 macOS（Intel / Apple Silicon）
// 多版本共存时，请从目标Photoshop的“文件 > 脚本 > 浏览”运行。
//
// V28更新：
// 1. 使用JavaScript兼容形式声明Photoshop目标，消除“应为 ;”误报
// 2. 增加Photoshop版本、发布通道、操作系统和处理器环境识别
// 3. 修复取消文件夹选择时的异常终止
// 4. 改进跨平台Unicode路径与macOS桌面写入回退
// 5. 固定TIFF字节序，保持Windows与macOS输出一致
// 6. 过滤macOS AppleDouble伴生文件
// 7. 保持原有像素、尺寸、DPI、ICC、LZW和JPG质量参数不变
//
// ==================================================



// ==================================================
// 全局变量
// ==================================================


// 错误日志

var errorList = [];



// 低PPI提醒

var lowPPIList = [];



// 高PPI提醒

var highPPIList = [];



// 输出数据

var reportData = [];



// DPI数据

var dpiData = [];



// 尺寸数据

var sizeData = [];



// ICC数据

var iccData = [];



// 输入色彩模式

var sourceModeData = [];



// 输出色彩模式

var outputModeData = [];




// 时间

var startTime = "";

var endTime = "";



// 计时

var startTick = 0;

var endTick = 0;

var runSeconds = 0;







// ==================================================
// 错误日志去重
// ==================================================


function addError(msg) {


    for (
        var i = 0; i < errorList.length; i++
    ) {


        if (
            errorList[i] == msg
        ) {


            return;


        }


    }



    errorList.push(msg);


}









// ==================================================
// 中文文件名读取
// ==================================================


function decodeFileName(file) {


    try {


        return File.decode(
            file.name
        );


    } catch (e) {


        return file.name;


    }


}









// ==================================================
// UTF-8 TXT写入
// ==================================================


function writeUTF8(file, text) {


    file.encoding =
        "UTF-8";


    file.open("w");


    file.write(

        "\uFEFF" +
        text

    );


    file.close();


}









// ==================================================
// 中国时间
// ==================================================


function getChinaTime() {


    var d =
        new Date();




    function zero(n) {


        return n < 10 ?

            "0" + n :

            n;


    }




    return (


        d.getFullYear() +

        "年" +

        zero(
            d.getMonth() + 1
        ) +

        "月" +

        zero(
            d.getDate()
        ) +

        "日 " +

        zero(
            d.getHours()
        ) +

        ":" +

        zero(
            d.getMinutes()
        ) +

        ":" +

        zero(
            d.getSeconds()
        )


    );


}









// ==================================================
// Photoshop静默模式
// ==================================================


function setSilentMode() {


    app.displayDialogs =
        DialogModes.NO;


}




function restoreDialogMode(mode) {


    app.displayDialogs =
        mode;


}









// ==================================================
// 获取色彩模式
// ==================================================


function getColorMode(doc) {


    switch (doc.mode) {


        case DocumentMode.CMYK:


            return "CMYK";




        case DocumentMode.RGB:


            return "RGB";




        case DocumentMode.GRAYSCALE:


            return "灰度";




        case DocumentMode.INDEXEDCOLOR:


            return "索引颜色";




        case DocumentMode.LAB:


            return "Lab";




        case DocumentMode.BITMAP:


            return "位图";




        case DocumentMode.MULTICHANNEL:


            return "多通道";




        default:


            return "未知";


    }


}
// ==================================================
// 获取ICC
// 指定文档读取
// ==================================================


function getICCProfile(doc) {


    try {


        app.activeDocument = doc;



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





        if (

            desc.hasKey(

                stringIDToTypeID("profile")

            )

        ) {


            return desc.getString(

                stringIDToTypeID("profile")

            );


        }





        return "未嵌入ICC";



    } catch (e) {



        return "ICC读取失败";


    }


}









// ==================================================
// 输出DPI
// Photoshop ppi ÷10
// ==================================================


function getOutputDPI(ppi) {


    return ppi / 10;


}









// ==================================================
// 横竖版
// ==================================================


function getOrientation(w, h) {


    if (w > h) {


        return "横版";


    }




    if (w < h) {


        return "竖版";


    }




    return "正方形";


}









// ==================================================
// cm格式
// ==================================================


function formatCM(value) {


    return value.toFixed(1);


}









// ==================================================
// mm格式
// ==================================================


function formatMM(value) {


    return value.toFixed(0);


}









// ==================================================
// DPI一致性检测
// 误差 <=1 dpi
// ==================================================


function checkDPIUniform() {


    if (

        dpiData.length <= 1

    ) {


        return true;


    }





    var base =

        dpiData[0].dpi;





    for (

        var i = 1;

        i < dpiData.length;

        i++

    ) {



        if (



            Math.abs(

                dpiData[i].dpi - base

            ) > 1



        ) {



            return false;



        }


    }





    return true;


}









// ==================================================
// DPI差异报告
// ==================================================


function getDPIDetail() {


    var text = "";





    for (

        var i = 0;

        i < dpiData.length;

        i++

    ) {



        text +=



            "  " +

            dpiData[i].name +

            "\n" +

            "  " +

            dpiData[i].dpi.toFixed(1) +

            " dpi\n\n";



    }





    return text;


}









// ==================================================
// 尺寸一致性检测
// 单位 cm
// 误差3mm
// ==================================================


function checkSizeUniform() {


    if (

        sizeData.length <= 1

    ) {


        return true;


    }





    var base =

        sizeData[0];





    for (

        var i = 1;

        i < sizeData.length;

        i++

    ) {



        if (



            Math.abs(

                sizeData[i].width -

                base.width

            ) > 0.3



            ||



            Math.abs(

                sizeData[i].height -

                base.height

            ) > 0.3



        ) {



            return false;



        }


    }





    return true;


}









// ==================================================
// 尺寸差异报告
// ==================================================


function getSizeDetail() {


    var text = "";





    for (

        var i = 0;

        i < sizeData.length;

        i++

    ) {



        text +=



            "  " +

            sizeData[i].name +

            "\n" +

            "  " +

            sizeData[i].width.toFixed(1) +

            " × " +

            sizeData[i].height.toFixed(1) +

            " cm\n\n";



    }





    return text;


}









// ==================================================
// ICC一致性检测
// ==================================================


function checkICCUniform() {


    if (

        iccData.length <= 1

    ) {


        return true;


    }





    var base =

        iccData[0].icc;





    for (

        var i = 1;

        i < iccData.length;

        i++

    ) {



        if (



            iccData[i].icc != base



        ) {



            return false;



        }


    }





    return true;


}









// ==================================================
// ICC差异报告
// ==================================================


function getICCDetail() {


    var text = "";





    for (

        var i = 0;

        i < iccData.length;

        i++

    ) {



        text +=



            "  " +

            iccData[i].name +

            "\n" +

            "  " +

            iccData[i].icc +

            "\n\n";



    }





    return text;


}
// ==================================================
// 色彩模式一致性检测
// ==================================================


function checkSourceModeUniform() {


    if (

        sourceModeData.length <= 1

    ) {


        return true;


    }





    var base =

        sourceModeData[0].mode;





    for (

        var i = 1;

        i < sourceModeData.length;

        i++

    ) {


        if (

            sourceModeData[i].mode != base

        ) {


            return false;


        }


    }





    return true;


}








// ==================================================
// 输入色彩模式报告
// ==================================================


function getSourceModeDetail() {


    var text = "";





    for (

        var i = 0;

        i < sourceModeData.length;

        i++

    ) {



        text +=



            "  " +

            sourceModeData[i].name +

            "\n" +

            "  " +

            sourceModeData[i].mode +

            "\n\n";



    }





    return text;


}









// ==================================================
// PPI异常报告
// ==================================================


function getPPIWarningDetail() {


    var text = "";





    if (

        lowPPIList.length > 0

    ) {


        text +=


            "低PPI提醒：\n";





        for (

            var i = 0;

            i < lowPPIList.length;

            i++

        ) {


            text +=


                "  " +

                lowPPIList[i] +

                "\n";



        }



        text += "\n";


    }








    if (

        highPPIList.length > 0

    ) {


        text +=


            "高PPI提醒：\n";





        for (

            var j = 0;

            j < highPPIList.length;

            j++

        ) {


            text +=


                "  " +

                highPPIList[j] +

                "\n";



        }



    }





    return text;


}










// ==================================================
// 生成检测提醒
// ==================================================


function getCheckWarning() {


    var text = "";





    if (

        !checkDPIUniform()

    ) {


        text +=


            "制作DPI存在差异：\n\n" +

            getDPIDetail() +

            "\n";


    }









    if (

        !checkSizeUniform()

    ) {


        text +=


            "成品尺寸存在差异：\n\n" +

            getSizeDetail() +

            "\n";


    }









    if (

        !checkICCUniform()

    ) {


        text +=


            "ICC配置存在差异，请确认颜色管理：\n\n" +

            getICCDetail() +

            "\n";


    }









    if (

        !checkSourceModeUniform()

    ) {


        text +=


            "输入文件色彩模式存在差异：\n\n" +

            getSourceModeDetail() +

            "\n";


    }









    var ppiWarning =

        getPPIWarningDetail();





    if (

        ppiWarning != ""

    ) {


        text +=


            ppiWarning +

            "\n";


    }









    if (

        text == ""

    ) {


        text =

            "无检测差异。\n";


    }





    return text;


}











// ==================================================
// 运行耗时
// ==================================================


function getRunSeconds() {


    return Math.round(


        (endTick - startTick) / 1000


    );


}









// ==================================================
// 安全关闭已有文件
// ==================================================


function safeCloseDocuments() {


    while (

        app.documents.length > 0

    ) {


        try {


            app.activeDocument.close(

                SaveOptions.DONOTSAVECHANGES

            );



        } catch (e) {


            break;


        }


    }


}











// ==================================================
// 选择文件夹
// ==================================================


function selectFolder(title) {
    return Folder.selectDialog(title);
}









// ==================================================
// 获取TIFF文件
// ==================================================


function getTiffFiles(folder) {


    return folder.getFiles(


        function(f) {


            if (

                f instanceof File

            ) {


                var n =

                    f.name.toLowerCase();





                return (


                    /\.tif$/i.test(n)

                    ||

                    /\.tiff$/i.test(n)


                );


            }





            return false;


        }


    );


}
// ==================================================
// 项目名称
// ==================================================


function getProjectName(file) {


    var name =

        decodeFileName(file);




    return name.replace(


        /\.[^\.]+$/,


        ""


    );


}









// ==================================================
// 生成版本文件
// ==================================================


function getVersionFile(file) {


    var folder =

        file.parent;




    var name =

        file.name.replace(


            /\.tif$/i,


            ""


        );




    var num = 2;


    var newFile;





    do {


        newFile =

            new File(


                folder +

                "/" +

                name +

                "_v0" +

                num +

                ".tif"


            );




        num++;




    }

    while (

        newFile.exists

    );





    return newFile;


}









// ==================================================
// 文件冲突检查
// ==================================================


function checkExistingFile(file) {


    if (

        !file.exists

    ) {


        return file;


    }




    return getVersionFile(file);


}











// ==================================================
// Photoshop进度
// ==================================================


function updateProgress(current, total, name) {


    try {


        app.updateProgress(


            current,


            total


        );




    } catch (e) {}

    v28SetProgressText(
        "正在处理：" + current + " / " + total + "\n" + name
    );



}











// ==================================================
// 主程序开始
// ==================================================


// V26 主流程保留为历史参考，不再执行。
function legacyV26Main() {


safeCloseDocuments();




startTick =

    new Date().getTime();




startTime =

    getChinaTime();











// ==================================================
// 输入文件夹
// ==================================================


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







if (

    files.length === 0

) {


    alert(


        "没有找到TIFF文件"


    );


    return;


}











// ==================================================
// 输出位置
// ==================================================


var outputParent =

    selectFolder(


        "请选择输出位置"


    );









var outputFolder =

    new Folder(



        outputParent +

        "/" +

        inputFolderName +

        "_制作文件"



    );








if (

    !outputFolder.exists

) {


    outputFolder.create();


}












// ==================================================
// 第一轮扫描
// 获取 DPI / 尺寸 / ICC / 输入模式
// ==================================================


for (

    var i = 0;

    i < files.length;

    i++

) {



    var oldDialog =

        app.displayDialogs;





    setSilentMode();





    try {



        var scanDoc =

            app.open(


                files[i]


            );








        // ======================
        // DPI
        // ======================


        var scanDPI =

            getOutputDPI(


                scanDoc.resolution


            );





        dpiData.push({


            name:

                decodeFileName(files[i]),



            dpi:

                scanDPI



        });









        // ======================
        // 尺寸
        // ======================


        sizeData.push({


            name:

                decodeFileName(files[i]),



            width:

                scanDoc.width.as("cm"),



            height:

                scanDoc.height.as("cm")



        });









        // ======================
        // ICC
        // ======================


        iccData.push({


            name:

                decodeFileName(files[i]),



            icc:

                getICCProfile(scanDoc)



        });









        // ======================
        // 输入色彩模式
        // ======================


        sourceModeData.push({


            name:

                decodeFileName(files[i]),



            mode:

                getColorMode(scanDoc)



        });









        // ======================
        // PPI异常检测
        // ======================


        if (

            scanDoc.resolution < 150

        ) {


            lowPPIList.push(



                decodeFileName(files[i])

                +

                "\n原始ppi："

                +

                scanDoc.resolution



            );


        }








        if (

            scanDoc.resolution > 1500

        ) {


            highPPIList.push(



                decodeFileName(files[i])

                +

                "\n原始ppi："

                +

                scanDoc.resolution



            );


        }









        scanDoc.close(


            SaveOptions.DONOTSAVECHANGES


        );





    } catch (e) {



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
// 第二轮输出开始
// ==================================================
// ==================================================
// 第二轮输出
// ==================================================


for (

    var j = 0;

    j < files.length;

    j++

) {



    updateProgress(


        j + 1,


        files.length,


        decodeFileName(files[j])


    );






    var oldMode =

        app.displayDialogs;





    setSilentMode();







    try {



        var doc =

            app.open(


                files[j]


            );









        // ======================
        // 原始ppi
        // ======================


        var sourcePPI =

            doc.resolution;








        // ======================
        // 输出dpi
        // ======================


        var outputDPI =

            getOutputDPI(


                sourcePPI


            );









        // ======================
        // 保持像素
        // 修改物理尺寸
        // ======================


        doc.resizeImage(



            undefined,



            undefined,



            outputDPI,



            ResampleMethod.NONE



        );









        // ======================
        // 获取最终尺寸
        // ======================


        var widthCM =

            doc.width.as("cm");





        var heightCM =

            doc.height.as("cm");









        // ======================
        // 文件名称
        // ======================


        var projectName =

            getProjectName(


                files[j]


            );









        var saveFile =

            new File(



                outputFolder

                +

                "/"

                +

                projectName

                +

                "_定稿.tif"



            );








        saveFile =

            checkExistingFile(


                saveFile


            );









        // ======================
        // TIFF设置
        // ======================


        var options =

            new TiffSaveOptions();








        options.imageCompression =

            TIFFEncoding.TIFFLZW;








        // 嵌入ICC

        options.embedColorProfile =

            true;









        // ======================
        // 保存TIFF
        // ======================


        doc.saveAs(



            saveFile,



            options,



            true,



            Extension.LOWERCASE



        );









        // ======================
        // 输出模式记录
        // ======================


        outputModeData.push({


            name:

                decodeFileName(saveFile),



            mode:

                getColorMode(doc)



        });









        // ======================
        // 输出数据记录
        // ======================


        reportData.push({



            name:

                projectName,



            width:

                widthCM,



            height:

                heightCM,



            dpi:

                outputDPI,



            mode:

                getColorMode(doc),



            file:

                decodeFileName(saveFile)



        });









        doc.close(


            SaveOptions.DONOTSAVECHANGES


        );






    } catch (e) {





        addError(

            decodeFileName(files[j])



            +

            "\n原因：输出失败"



        );








        try {



            if (


                app.documents.length > 0


            ) {



                app.activeDocument.close(


                    SaveOptions.DONOTSAVECHANGES


                );



            }




        } catch (closeError) {}







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





endTick =

    new Date().getTime();





runSeconds =

    getRunSeconds();
// ==================================================
// 输出报告文件
// ==================================================


var reportFile =

    new File(

        outputFolder + "/" + inputFolderName + "_输出报告.txt"

    );





var reportText = "";





reportText +=

    "========================\n" +

    "  输出报告\n" +

    "========================\n\n";





// ==================================================
// 完稿时间
// ==================================================


reportText +=

    "完稿时间：\n" +

    "  " +

    endTime +

    "\n\n";





// ==================================================
// 文件数量
// ==================================================


reportText +=

    "文件数量：\n" +

    "  " +

    reportData.length +

    "\n\n";





// ==================================================
// 成品尺寸
// ==================================================


reportText +=

    "成品尺寸：\n";








if (

    reportData.length > 0

) {




    var firstWidth =

        reportData[0].width;





    var firstHeight =

        reportData[0].height;





    var sameSize = true;








    for (

        var r = 1;

        r < reportData.length;

        r++

    ) {





        if (



            Math.abs(

                reportData[r].width -

                firstWidth

            ) > 0.3



            ||



            Math.abs(

                reportData[r].height -

                firstHeight

            ) > 0.3



        ) {



            sameSize = false;



        }



    }









    if (

        sameSize

    ) {




        reportText +=

            "  " +

            firstWidth.toFixed(1) +

            " × " +

            firstHeight.toFixed(1) +

            " cm\n\n";


    } else {




        reportText +=

            "  检测到成品尺寸存在差异。\n\n";


    }



}











// ==================================================
// 制作DPI
// ==================================================


reportText +=

    "制作DPI：\n";








if (

    checkDPIUniform()

) {




    if (

        dpiData.length > 0

    ) {



        reportText +=

            "  " +

            dpiData[0].dpi.toFixed(1) +

            " dpi\n\n";


    }




} else {




    reportText +=

        "  检测到DPI存在差异。\n\n" +

        getDPIDetail();


}











// ==================================================
// 输入色彩模式
// ==================================================


reportText +=

    "输入文件色彩模式：\n";








if (

    checkSourceModeUniform()

) {




    if (

        sourceModeData.length > 0

    ) {



        reportText +=

            "  统一：" +

            sourceModeData[0].mode +

            "\n\n";


    }



} else {




    reportText +=

        "  检测到输入色彩模式差异：\n\n" +

        getSourceModeDetail();



}











// ==================================================
// 输出色彩模式
// ==================================================


reportText +=

    "输出文件色彩模式：\n";








if (

    outputModeData.length > 0

) {




    reportText +=

        "  " +

        outputModeData[0].mode +

        "\n\n";


} else {



    reportText +=

        "  未知\n\n";


}











// ==================================================
// ICC
// ==================================================


reportText +=

    "ICC：\n";








if (

    checkICCUniform()

) {




    if (

        iccData.length > 0

    ) {



        reportText +=

            "  " +

            iccData[0].icc +

            "\n\n";


    }




} else {



    reportText +=

        "  检测到ICC配置存在差异，请确认颜色管理。\n\n" +

        getICCDetail();



}











// ==================================================
// 输出文件列表
// ==================================================


reportText +=

    "输出文件：\n";








for (

    var f = 0;

    f < reportData.length;

    f++

) {




    reportText +=

        "\n" +

        "  " +

        reportData[f].file +

        "\n";



}


// ==================================================
// 写入客户报告
// ==================================================


var reportFile =

    new File(

        outputFolder + "/" + inputFolderName + "_输出报告.txt"

    );





writeUTF8(

    reportFile,

    reportText

);









// ==================================================
// 桌面运行日志
// ==================================================


var logFile =

    new File(

        Folder.desktop + "/" + inputFolderName + "_运行日志.txt"

    );





var logText = "";





logText +=

    "========================\n" +

    "运行日志\n" +

    "========================\n\n";








// ==================================================
// 时间
// ==================================================


logText +=

    "开始时间：\n" +

    "  " +

    startTime +

    "\n\n";






logText +=

    "结束时间：\n" +

    "  " +

    endTime +

    "\n\n";






logText +=

    "运行耗时：\n" +

    "  " +

    runSeconds +

    " 秒\n\n";








// ==================================================
// 文件统计
// ==================================================


logText +=

    "扫描文件数量：\n" +

    "  " +

    files.length +

    "\n\n";






logText +=

    "成功输出数量：\n" +

    "  " +

    reportData.length +

    "\n\n";









// ==================================================
// 检测提醒
// ==================================================


var warningText =

    getCheckWarning();





if (

    warningText !=

    "无检测差异。\n"



) {




    logText +=

        "========================\n" +

        "检测提醒\n" +

        "========================\n\n" +

        warningText +

        "\n";


} else {



    logText +=

        "检测提醒：\n" +

        "  无\n\n";


}










// ==================================================
// 错误日志
// ==================================================


if (

    errorList.length > 0

) {




    logText +=

        "========================\n" +

        "错误日志\n" +

        "========================\n";





    for (

        var e = 0;

        e < errorList.length;

        e++

    ) {




        logText +=

            "\n" +

            "  " +

            errorList[e] +

            "\n";


    }





} else {



    logText +=

        "错误日志：\n" +

        "  无\n\n";


}









// ==================================================
// 低PPI提醒
// ==================================================


if (

    lowPPIList.length > 0

) {




    logText +=

        "\n" +

        "低PPI提醒：\n";





    for (

        var p = 0;

        p < lowPPIList.length;

        p++

    ) {




        logText +=

            "\n" +

            "  " +

            lowPPIList[p] +

            "\n";


    }





}









// ==================================================
// 高PPI提醒
// ==================================================


if (

    highPPIList.length > 0

) {




    logText +=

        "\n" +

        "高PPI提醒：\n";





    for (

        var hp = 0;

        hp < highPPIList.length;

        hp++

    ) {




        logText +=

            "\n" +

            "  " +

            highPPIList[hp] +

            "\n";


    }





}









// ==================================================
// 作者信息
// ==================================================


logText +=

    "\n\n" +

    "========================\n" +

    "联系作者：\n" +

    "huaping.woo@gmail.com\n";












// ==================================================
// 写入运行日志
// ==================================================


writeUTF8(


    logFile,


    logText


);









// ==================================================
// 清除状态栏
// ==================================================


try {


    app.updateStatusBarMessage(


        "批处理完成"


    );


} catch (e) {}









// ==================================================
// 结束
// ==================================================

}


// ==================================================
// V28 跨版本与跨平台兼容层
// ==================================================

var V28_MIN_PHOTOSHOP_MAJOR = 23;
var V28_MAX_PHOTOSHOP_MAJOR = 27;


function v28SingleLine(value) {
    return String(value || "").replace(/[\r\n]+/g, " ");
}


function v28SetProgressText(message) {
    try {
        app.changeProgressText(message);
        return;
    } catch (changeProgressError) {}

    try {
        app.updateStatusBarMessage(message);
    } catch (statusBarError) {}
}


function v28JoinPath(parent, leafName) {
    var base = "";
    var encodedLeaf = String(leafName);

    try {
        base = parent.absoluteURI;
    } catch (absoluteURIError) {}

    if (!base) {
        base = String(parent);
    }

    try {
        encodedLeaf = File.encode(encodedLeaf);
    } catch (encodeError) {
        try {
            encodedLeaf = encodeURIComponent(encodedLeaf);
        } catch (fallbackEncodeError) {}
    }

    if (base.charAt(base.length - 1) != "/") {
        base += "/";
    }

    return base + encodedLeaf;
}


function v28PhotoshopLabel(major, isBeta) {
    if (isBeta) {
        return "Adobe Photoshop Beta";
    }

    switch (major) {
        case 23:
            return "Adobe Photoshop 2022";
        case 24:
            return "Adobe Photoshop 2023";
        case 25:
            return "Adobe Photoshop 2024";
        case 26:
            return "Adobe Photoshop 2025";
        case 27:
            return "Adobe Photoshop 2026";
        default:
            return "Adobe Photoshop";
    }
}


function v28ProcessorLabel(isMac, osText) {
    if (!isMac) {
        return "由Photoshop运行时管理";
    }

    var systemInformation = osText || "";

    try {
        if (app.systemInformation !== undefined) {
            systemInformation += " " + String(app.systemInformation);
        }
    } catch (systemInformationError) {}

    if (/apple\s*m\d|apple silicon|arm64|aarch64/i.test(systemInformation)) {
        return "Apple Silicon";
    }

    if (/intel/i.test(systemInformation)) {
        return "Intel";
    }

    if (/x86_64|x64/i.test(systemInformation)) {
        return "Intel / Rosetta";
    }

    return "Intel / Apple Silicon通用（未识别具体架构）";
}


function v28InspectEnvironment() {
    var appName = "";
    var appPath = "";
    var version = "";
    var osText = "";
    var fileSystem = "";

    try {
        appName = String(app.name);
    } catch (appNameError) {}

    try {
        appPath = String(app.path.fsName);
    } catch (appPathError) {}

    try {
        version = String(app.version);
    } catch (versionError) {}

    try {
        osText = String($.os);
    } catch (osError) {}

    try {
        fileSystem = String(File.fs);
    } catch (fileSystemError) {}

    var major = parseInt(version.split(".")[0], 10);

    if (isNaN(major)) {
        major = 0;
    }

    var identity = appName + " " + appPath;
    var isPhotoshop = /photoshop/i.test(identity);
    var isBeta = /beta/i.test(identity);
    var isMac = /mac/i.test(osText) || /mac/i.test(fileSystem);
    var isWindows = /win/i.test(osText) || /win/i.test(fileSystem);
    var canRun = isPhotoshop && !(major > 0 && major < V28_MIN_PHOTOSHOP_MAJOR);
    var warning = "";
    var compatibilityStatus = "已纳入兼容范围";

    if (!isPhotoshop) {
        warning = "当前宿主不是Adobe Photoshop。";
        compatibilityStatus = "不支持";
    } else if (major > 0 && major < V28_MIN_PHOTOSHOP_MAJOR) {
        warning = "Photoshop版本低于2022（23.x）。";
        compatibilityStatus = "不支持";
    } else if (major === 0) {
        warning = "无法识别Photoshop版本，将按兼容模式继续。";
        compatibilityStatus = "版本未识别";
    } else if (major > V28_MAX_PHOTOSHOP_MAJOR) {
        warning = isBeta ?
            "当前Photoshop Beta主版本高于2026范围，将按兼容模式继续。" :
            "当前Photoshop版本高于已验证范围，将按兼容模式继续。";
        compatibilityStatus = isBeta ?
            "Beta兼容模式" : "新版本兼容模式";
    }

    if (!isMac && !isWindows) {
        warning += (warning ? " " : "") +
            "无法识别操作系统，将使用Adobe跨平台文件接口。";
        compatibilityStatus = compatibilityStatus == "已纳入兼容范围" ?
            "平台未识别" : compatibilityStatus;
    }

    return {
        appName: appName || "Adobe Photoshop",
        appVersion: version || "未知",
        productLabel: v28PhotoshopLabel(major, isBeta),
        major: major,
        isBeta: isBeta,
        isMac: isMac,
        isWindows: isWindows,
        osLabel: isMac ? "macOS" : (isWindows ? "Windows" : "未知系统"),
        osText: v28SingleLine(osText),
        processorLabel: v28ProcessorLabel(isMac, osText),
        compatibilityStatus: compatibilityStatus,
        warning: warning,
        canRun: canRun
    };
}


function v28ValidateEnvironment(environment) {
    if (environment.canRun) {
        return true;
    }

    alert(
        "当前运行环境不受支持，批处理尚未开始。\n\n" +
        "支持范围：Adobe Photoshop 2022-2026及Photoshop Beta\n" +
        "当前环境：" + environment.appName + " " +
        environment.appVersion + "\n\n" +
        environment.warning
    );

    return false;
}


function v28BuildEnvironmentText(environment) {
    if (!environment) {
        return "运行环境：\n  未记录\n\n";
    }

    var text = "运行环境：\n";
    text += "  应用：" + environment.productLabel + "\n";
    text += "  版本：" + environment.appVersion + "\n";
    text += "  系统：" + environment.osLabel;

    if (environment.osText) {
        text += "（" + environment.osText + "）";
    }

    text += "\n";
    text += "  处理器：" + environment.processorLabel + "\n";
    text += "  兼容状态：" + environment.compatibilityStatus + "\n\n";

    return text;
}


// V27生产核心保留，由V28兼容层调用。

function v27ErrorText(e) {
    var text = "未知错误";

    try {
        if (e && e.message) {
            text = e.message;
        } else if (e) {
            text = String(e);
        }

        if (e && e.number !== undefined) {
            text += "（错误编号：" + e.number + "）";
        }

        if (e && e.line !== undefined) {
            text += "（脚本行：" + e.line + "）";
        }
    } catch (ignore) {}

    return text;
}


function v27AddAnomaly(list, type, fileName, reason) {
    var safeType = type || "其他异常";
    var safeFileName = fileName || "批处理任务";
    var safeReason = reason || "未知原因";

    for (var i = 0; i < list.length; i++) {
        if (
            list[i].type == safeType &&
            list[i].fileName == safeFileName &&
            list[i].reason == safeReason
        ) {
            return;
        }
    }

    list.push({
        type: safeType,
        fileName: safeFileName,
        reason: safeReason
    });
}


function v27DecodeName(value) {
    try {
        return File.decode(String(value));
    } catch (fileDecodeError) {
        try {
            return decodeURIComponent(value);
        } catch (uriDecodeError) {
            return value;
        }
    }
}


function v27DateStamp() {
    var d = new Date();

    function pad(n) {
        return n < 10 ? "0" + n : String(n);
    }

    return String(d.getFullYear()) + pad(d.getMonth() + 1) + pad(d.getDate());
}


function v27SanitizeFilePart(text) {
    return String(text).replace(/[\\\/:*?"<>|]/g, "_");
}


function v27ProjectName(folder) {
    var original = v27DecodeName(folder.name);
    var name = original;
    var previous = "";

    name = name.replace(/^\s*\d{8}[\s_\-]*/, "");

    do {
        previous = name;
        name = name.replace(/[\s_\-]+v\d+(?:\.\d+)*$/i, "");
        name = name.replace(/[\s_\-]+(?:制作文件|输出文件|交付文件|转曲|定稿)$/i, "");
        name = name.replace(/^\s+|\s+$/g, "");
    } while (name != previous);

    if (!name) {
        name = original;
    }

    return v27SanitizeFilePart(name);
}


function v27BaseName(file) {
    return v27SanitizeFilePart(
        decodeFileName(file).replace(/\.(?:tif|tiff|jpg|jpeg)$/i, "")
    );
}


function v27OutputExtension(file) {
    return /\.jpe?g$/i.test(file.name) ? ".jpg" : ".tif";
}


function v27GetProductionFiles(folder) {
    var files = folder.getFiles(function(f) {
        if (!(f instanceof File)) {
            return false;
        }

        var decodedName = decodeFileName(f);

        if (/^\._/.test(decodedName)) {
            return false;
        }

        return /\.(?:tif|tiff|jpg|jpeg)$/i.test(decodedName);
    });

    if (!files) {
        return [];
    }

    files.sort(function(a, b) {
        var an = decodeFileName(a).toLowerCase();
        var bn = decodeFileName(b).toLowerCase();
        return an < bn ? -1 : (an > bn ? 1 : 0);
    });

    return files;
}


function v27VersionedOutputFile(folder, baseName, extension) {
    var first = new File(
        v28JoinPath(folder, baseName + "_定稿" + extension)
    );

    if (!first.exists) {
        return first;
    }

    var version = 2;
    var candidate;

    do {
        var versionText = version < 10 ? "0" + version : String(version);
        candidate = new File(v28JoinPath(
            folder,
            baseName + "_定稿_v" + versionText + extension
        ));
        version++;
    } while (candidate.exists);

    return candidate;
}


function v27PrepareOpenDocuments() {
    var previousDialogs = app.displayDialogs;
    var existingDocuments = [];
    var i;

    try {
        app.displayDialogs = DialogModes.ALL;

        for (i = 0; i < app.documents.length; i++) {
            existingDocuments.push(app.documents[i]);
        }

        // 先保存全部文档；任一保存失败时，不关闭其余文档。
        for (i = 0; i < existingDocuments.length; i++) {
            var documentToSave = existingDocuments[i];

            try {
                app.activeDocument = documentToSave;
                documentToSave.save();
            } catch (saveError) {
                alert(
                    "无法保存文档：\n" +
                    documentToSave.name +
                    "\n\n原因：" +
                    v27ErrorText(saveError) +
                    "\n\n批处理尚未开始。"
                );
                return false;
            }
        }

        // 全部保存成功后再关闭，避免保存阶段出现部分关闭。
        for (i = existingDocuments.length - 1; i >= 0; i--) {
            var documentToClose = existingDocuments[i];

            try {
                documentToClose.close(SaveOptions.DONOTSAVECHANGES);
            } catch (closeError) {
                alert(
                    "无法关闭文档：\n" +
                    documentToClose.name +
                    "\n\n原因：" +
                    v27ErrorText(closeError) +
                    "\n\n批处理尚未开始。"
                );
                return false;
            }
        }

        return true;
    } finally {
        app.displayDialogs = previousDialogs;
    }
}


function v27CheckWritableFolder(folder) {
    var probe = new File(
        v28JoinPath(
            folder,
            "_even_v28_write_test_" + new Date().getTime() + ".tmp"
        )
    );

    var opened = false;
    var wrote = false;
    var closed = true;
    var removed = true;

    try {
        probe.encoding = "UTF-8";

        opened = probe.open("w");

        if (opened) {
            wrote = probe.write("write-test") !== false;
        }
    } catch (e) {
        wrote = false;
    } finally {
        try {
            if (probe.opened) {
                closed = probe.close() !== false;
            }
        } catch (ignore) {
            closed = false;
        }

        try {
            if (probe.exists) {
                removed = probe.remove() !== false && !probe.exists;
            }
        } catch (ignoreRemove) {
            removed = false;
        }
    }

    return opened && wrote && closed && removed && !probe.exists;
}


function v27TryCloseDocument(doc, fileName, anomalies, unclosedDocs) {
    if (!doc) {
        return true;
    }

    try {
        doc.close(SaveOptions.DONOTSAVECHANGES);
        return true;
    } catch (firstError) {
        try {
            app.activeDocument = doc;
            doc.close(SaveOptions.DONOTSAVECHANGES);
            return true;
        } catch (secondError) {
            v27AddAnomaly(
                anomalies,
                "文档关闭失败",
                fileName,
                v27ErrorText(secondError)
            );

            if (unclosedDocs) {
                unclosedDocs.push({
                    doc: doc,
                    fileName: fileName
                });
            }

            return false;
        }
    }
}


function v27RetryUnclosedDocuments(unclosedDocs, anomalies) {
    for (var i = 0; i < unclosedDocs.length; i++) {
        try {
            unclosedDocs[i].doc.close(SaveOptions.DONOTSAVECHANGES);
        } catch (e) {
            v27AddAnomaly(
                anomalies,
                "文档最终关闭失败",
                unclosedDocs[i].fileName,
                v27ErrorText(e)
            );
        }
    }
}


function v27CleanupMemory(fileName, anomalies) {
    try {
        app.purge(PurgeTarget.ALLCACHES);
    } catch (e) {
        v27AddAnomaly(
            anomalies,
            "缓存清理失败",
            fileName,
            v27ErrorText(e)
        );
    }

    try {
        if ($.gc) {
            $.gc();
        }
    } catch (gcError) {
        v27AddAnomaly(
            anomalies,
            "脚本内存清理失败",
            fileName,
            v27ErrorText(gcError)
        );
    }
}


function v27NormalizeICC(icc) {
    if (!icc || icc == "未嵌入ICC") {
        return "未嵌入颜色配置文件";
    }

    return icc;
}


function v27SaveProductionFile(doc, outputFile, extension) {
    if (outputFile.exists) {
        throw new Error("目标文件已存在，未执行覆盖");
    }

    try {
        if (extension == ".jpg") {
            var jpgOptions = new JPEGSaveOptions();
            jpgOptions.quality = 12;
            jpgOptions.embedColorProfile = true;
            jpgOptions.formatOptions = FormatOptions.STANDARDBASELINE;

            doc.saveAs(
                outputFile,
                jpgOptions,
                true,
                Extension.LOWERCASE
            );
        } else {
            var tifOptions = new TiffSaveOptions();
            tifOptions.imageCompression = TIFFEncoding.TIFFLZW;
            tifOptions.embedColorProfile = true;
            // 固定为Windows既有字节序，避免macOS使用不同默认值。
            tifOptions.byteOrder = ByteOrder.IBM;

            doc.saveAs(
                outputFile,
                tifOptions,
                true,
                Extension.LOWERCASE
            );
        }

        if (!outputFile.exists || outputFile.length <= 0) {
            throw new Error("Photoshop未生成有效目标文件");
        }
    } catch (saveError) {
        var partialCleanupError = "";

        try {
            if (outputFile.exists) {
                if (outputFile.remove() === false || outputFile.exists) {
                    partialCleanupError = "删除返回失败";
                }
            }
        } catch (removePartialError) {
            partialCleanupError = v27ErrorText(removePartialError);
        }

        if (partialCleanupError) {
            throw new Error(
                v27ErrorText(saveError) +
                "；同时无法删除半成品：" + outputFile.fsName +
                "（" + partialCleanupError + "）"
            );
        }

        throw saveError;
    }
}


function v27SafeWriteUTF8(file, text) {
    var opened = false;
    var existedBefore = file.exists;

    if (existedBefore) {
        throw new Error("目标文本文件已存在，未执行覆盖");
    }

    try {
        file.encoding = "UTF-8";
        opened = file.open("w");

        if (!opened) {
            throw new Error("无法打开文本文件进行写入");
        }

        if (!file.write("\uFEFF" + text)) {
            throw new Error("文本内容写入失败");
        }

        if (file.close() === false) {
            throw new Error("文本文件关闭失败");
        }

        opened = false;

        if (!file.exists || file.length <= 0) {
            throw new Error("未生成有效文本文件");
        }
    } catch (writeError) {
        var cleanupErrorText = "";

        try {
            if (opened && file.opened) {
                if (file.close() === false) {
                    cleanupErrorText = "关闭失败";
                }
            }
        } catch (closeError) {
            cleanupErrorText = v27ErrorText(closeError);
        }

        opened = false;

        try {
            if (!existedBefore && file.exists) {
                if (file.remove() === false || file.exists) {
                    cleanupErrorText += (cleanupErrorText ? "；" : "") +
                        "删除失败";
                }
            }
        } catch (removeError) {
            cleanupErrorText += (cleanupErrorText ? "；" : "") +
                v27ErrorText(removeError);
        }

        if (cleanupErrorText) {
            throw new Error(
                v27ErrorText(writeError) +
                "；同时无法清理未完成文本：" + file.fsName +
                "（" + cleanupErrorText + "）"
            );
        }

        throw writeError;
    } finally {
        try {
            if (opened && file.opened) {
                file.close();
            }
        } catch (finalCloseError) {
        }
    }
}


function v27NumberText(value) {
    var rounded = Math.round(value);
    return Math.abs(value - rounded) < 0.05 ? String(rounded) : value.toFixed(1);
}


function v27GroupRecords(records, keyFunction, labelFunction) {
    var groups = [];

    for (var i = 0; i < records.length; i++) {
        var key = keyFunction(records[i]);
        var found = null;

        for (var g = 0; g < groups.length; g++) {
            if (groups[g].key == key) {
                found = groups[g];
                break;
            }
        }

        if (found) {
            found.count++;
            found.records.push(records[i]);
        } else {
            groups.push({
                key: key,
                label: labelFunction(records[i]),
                count: 1,
                records: [records[i]]
            });
        }
    }

    return groups;
}


function v28HasSizeDifference(records) {
    if (records.length <= 1) {
        return false;
    }

    var base = records[0];

    for (var i = 1; i < records.length; i++) {
        if (
            Math.abs(records[i].width - base.width) > 0.300001 ||
            Math.abs(records[i].height - base.height) > 0.300001
        ) {
            return true;
        }
    }

    return false;
}


function v28HasDPIDifference(records) {
    if (records.length <= 1) {
        return false;
    }

    var base = records[0].dpi;

    for (var i = 1; i < records.length; i++) {
        if (Math.abs(records[i].dpi - base) > 1) {
            return true;
        }
    }

    return false;
}


function v27RegisterDifferenceAnomalies(records, anomalies) {
    var sizeGroups = v27GroupRecords(
        records,
        function(r) {
            return r.width.toFixed(1) + "x" + r.height.toFixed(1);
        },
        function(r) {
            return r.width.toFixed(1) + " × " + r.height.toFixed(1) + " cm";
        }
    );

    // 沿用既有生产容差：尺寸差不超过0.3 cm不报警。
    if (v28HasSizeDifference(records)) {
        for (var i = 0; i < records.length; i++) {
            v27AddAnomaly(
                anomalies,
                "制作尺寸存在差异",
                records[i].fileName,
                records[i].width.toFixed(1) + " × " +
                records[i].height.toFixed(1) + " cm"
            );
        }
    }

    var dpiGroups = v27GroupRecords(
        records,
        function(r) {
            return r.dpi.toFixed(1);
        },
        function(r) {
            return v27NumberText(r.dpi) + " DPI";
        }
    );

    // 沿用既有生产容差：DPI差不超过1不报警。
    if (v28HasDPIDifference(records)) {
        for (var d = 0; d < records.length; d++) {
            v27AddAnomaly(
                anomalies,
                "制作分辨率存在差异",
                records[d].fileName,
                v27NumberText(records[d].dpi) + " DPI"
            );
        }
    }

    var colorGroups = v27GroupRecords(
        records,
        function(r) {
            return r.mode + "|" + r.icc;
        },
        function(r) {
            return r.mode + " / " + r.icc;
        }
    );

    if (colorGroups.length > 1) {
        for (var c = 0; c < records.length; c++) {
            v27AddAnomaly(
                anomalies,
                "色彩模式或ICC存在差异",
                records[c].fileName,
                records[c].mode + " / " + records[c].icc
            );
        }
    }
}


function v27FormatDuration(seconds) {
    var total = Math.max(0, Math.round(seconds));
    var hours = Math.floor(total / 3600);
    var minutes = Math.floor((total % 3600) / 60);
    var secs = total % 60;
    var parts = [];

    if (hours > 0) {
        parts.push(hours + "小时");
    }

    if (minutes > 0 || hours > 0) {
        parts.push(minutes + "分");
    }

    parts.push(secs + "秒");
    return parts.join("");
}


function v27BuildDeliveryText(projectName, endTimeText, records) {
    var text = "";
    text += "========================\n";
    text += projectName + " 交付说明\n";
    text += "========================\n\n";
    text += "完稿时间：\n" + endTimeText + "\n\n";
    text += "文件数量：\n" + records.length + " 个\n\n";

    var sizeGroups = v27GroupRecords(
        records,
        function(r) {
            return r.width.toFixed(1) + "x" + r.height.toFixed(1);
        },
        function(r) {
            return r.width.toFixed(1) + " × " + r.height.toFixed(1) + " cm";
        }
    );

    text += "制作尺寸：\n";
    for (var s = 0; s < sizeGroups.length; s++) {
        text += sizeGroups[s].label + "（" + sizeGroups[s].count + "个文件）\n";
    }
    text += "\n";

    var dpiGroups = v27GroupRecords(
        records,
        function(r) {
            return r.dpi.toFixed(1);
        },
        function(r) {
            return v27NumberText(r.dpi) + " DPI";
        }
    );

    text += "制作分辨率：\n";
    for (var d = 0; d < dpiGroups.length; d++) {
        text += dpiGroups[d].label + "（" + dpiGroups[d].count + "个文件）\n";
    }
    text += "\n";

    var colorGroups = v27GroupRecords(
        records,
        function(r) {
            return r.mode + "|" + r.icc;
        },
        function(r) {
            return r.mode + "\n" + r.icc;
        }
    );

    text += "色彩模式：\n";
    for (var c = 0; c < colorGroups.length; c++) {
        text += colorGroups[c].label + "（" + colorGroups[c].count + "个文件）\n";

        if (c < colorGroups.length - 1) {
            text += "\n";
        }
    }
    text += "\n\n";

    text += "交付文件列表：\n";
    for (var f = 0; f < records.length; f++) {
        text += records[f].fileName + "\n";
    }

    return text;
}


function v27BuildAnomalyText(anomalies) {
    if (anomalies.length === 0) {
        return "异常提醒：\n无\n\n";
    }

    var types = [];

    for (var i = 0; i < anomalies.length; i++) {
        var group = null;

        for (var t = 0; t < types.length; t++) {
            if (types[t].type == anomalies[i].type) {
                group = types[t];
                break;
            }
        }

        if (!group) {
            group = {
                type: anomalies[i].type,
                items: []
            };
            types.push(group);
        }

        group.items.push(anomalies[i]);
    }

    var text = "异常提醒：\n\n";

    for (var g = 0; g < types.length; g++) {
        text += types[g].type + "：" + types[g].items.length + "个文件\n";

        for (var n = 0; n < types[g].items.length; n++) {
            text += "  文件：" + types[g].items[n].fileName + "\n";
            text += "  原因：" + types[g].items[n].reason + "\n\n";
        }
    }

    return text;
}


function v27BuildRunLogText(
    projectName,
    scannedCount,
    successCount,
    runSecondsValue,
    anomalies,
    environment
) {
    var failedCount = scannedCount - successCount;
    var text = "";

    text += "========================\n";
    text += projectName + " 运行日志\n";
    text += "========================\n\n";
    text += "扫描文件数量：\n" + scannedCount + " 个\n\n";
    text += "成功输出数量：\n" + successCount + " 个\n\n";
    text += "失败文件数量：\n" + failedCount + " 个\n\n";
    text += "运行耗时：\n" + v27FormatDuration(runSecondsValue) + "\n\n";
    text += v28BuildEnvironmentText(environment);
    text += v27BuildAnomalyText(anomalies);
    text += "联系作者：\n";
    text += "huaping.woo@gmail.com\n\n\n";
    text += "                         by Huaping Woo\n";

    return text;
}


function v28VersionedTextFile(folder, baseName) {
    var first = new File(v28JoinPath(folder, baseName + ".txt"));

    if (!first.exists) {
        return first;
    }

    var version = 2;
    var candidate;

    do {
        var versionText = version < 10 ? "0" + version : String(version);
        candidate = new File(v28JoinPath(
            folder,
            baseName + "_v" + versionText + ".txt"
        ));
        version++;
    } while (candidate.exists);

    return candidate;
}


function v28FolderKey(folder) {
    try {
        return String(folder.absoluteURI).toLowerCase();
    } catch (absoluteURIError) {
        return String(folder).toLowerCase();
    }
}


function v28AddUniqueFolder(folders, folder) {
    if (!folder) {
        return;
    }

    var key = v28FolderKey(folder);

    for (var i = 0; i < folders.length; i++) {
        if (v28FolderKey(folders[i]) == key) {
            return;
        }
    }

    folders.push(folder);
}


function v28CurrentRunLogText(elapsedSeconds) {
    return v27BuildRunLogText(
        v27RuntimeState.projectName,
        v27RuntimeState.scannedCount,
        v27RuntimeState.successCount,
        elapsedSeconds,
        v27RuntimeState.anomalies,
        v27RuntimeState.environment
    );
}


function v28WriteRunLog(dateStamp, elapsedSeconds, fallbackFolder) {
    var folders = [];
    var baseName = dateStamp + "_" +
        v27SanitizeFilePart(v27RuntimeState.projectName) +
        "_运行日志";
    var lastError = "";
    var desktopFolderKey = "";

    try {
        var desktopFolder = Folder.desktop;
        v28AddUniqueFolder(folders, desktopFolder);
        desktopFolderKey = v28FolderKey(desktopFolder);
    } catch (desktopFolderError) {
        v27AddAnomaly(
            v27RuntimeState.anomalies,
            "桌面目录不可用",
            "运行日志",
            v27ErrorText(desktopFolderError)
        );
    }

    v28AddUniqueFolder(folders, fallbackFolder);

    try {
        v28AddUniqueFolder(folders, Folder.temp);
    } catch (tempFolderError) {
        v27AddAnomaly(
            v27RuntimeState.anomalies,
            "临时目录不可用",
            "运行日志",
            v27ErrorText(tempFolderError)
        );
    }

    for (var i = 0; i < folders.length; i++) {
        var runLogFile = null;

        try {
            runLogFile = v28VersionedTextFile(folders[i], baseName);
            v27SafeWriteUTF8(
                runLogFile,
                v28CurrentRunLogText(elapsedSeconds)
            );

            return {
                file: runLogFile,
                usedFallback: !desktopFolderKey ||
                    v28FolderKey(folders[i]) != desktopFolderKey,
                errorText: ""
            };
        } catch (writeError) {
            lastError = v27ErrorText(writeError);

            v27AddAnomaly(
                v27RuntimeState.anomalies,
                "运行日志写入失败",
                runLogFile ? runLogFile.fsName : "运行日志",
                lastError
            );
        }
    }

    return {
        file: null,
        usedFallback: false,
        errorText: lastError || "没有可写的日志目录"
    };
}


function v28WriteRunLogSafely(dateStamp, elapsedSeconds, fallbackFolder) {
    try {
        return v28WriteRunLog(dateStamp, elapsedSeconds, fallbackFolder);
    } catch (unexpectedLogError) {
        return {
            file: null,
            usedFallback: false,
            errorText: v27ErrorText(unexpectedLogError)
        };
    }
}


var v27RuntimeState = {
    projectName: "批处理",
    scannedCount: 0,
    successCount: 0,
    startMilliseconds: 0,
    anomalies: [],
    environment: null,
    outputFolder: null,
    batchStarted: false
};


function runV27() {
    var anomalies = [];
    var environment = v28InspectEnvironment();

    v27RuntimeState.projectName = "批处理";
    v27RuntimeState.scannedCount = 0;
    v27RuntimeState.successCount = 0;
    v27RuntimeState.startMilliseconds = 0;
    v27RuntimeState.anomalies = anomalies;
    v27RuntimeState.environment = environment;
    v27RuntimeState.outputFolder = null;
    v27RuntimeState.batchStarted = false;

    if (!v28ValidateEnvironment(environment)) {
        return;
    }

    var inputFolder = selectFolder("请选择需要处理的TIFF或JPG文件夹");

    if (!inputFolder) {
        return;
    }

    var outputParent = selectFolder("请选择输出位置");

    if (!outputParent) {
        return;
    }

    var projectName = v27ProjectName(inputFolder);
    v27RuntimeState.projectName = projectName;
    var dateStamp = v27DateStamp();
    var files = v27GetProductionFiles(inputFolder);
    v27RuntimeState.scannedCount = files.length;

    if (files.length === 0) {
        alert("没有找到TIFF或JPG文件");
        return;
    }

    var inputFolderName = v27SanitizeFilePart(
        v27DecodeName(inputFolder.name)
    );
    var outputFolder = new Folder(
        v28JoinPath(outputParent, inputFolderName + "_制作文件")
    );

    if (!outputFolder.exists && !outputFolder.create()) {
        alert("无法创建输出文件夹：\n" + outputFolder.fsName);
        return;
    }

    if (!v27CheckWritableFolder(outputFolder)) {
        alert("输出文件夹无法写入：\n" + outputFolder.fsName);
        return;
    }

    v27RuntimeState.outputFolder = outputFolder;

    if (!v27PrepareOpenDocuments()) {
        return;
    }

    v27RuntimeState.batchStarted = true;

    var startMilliseconds = new Date().getTime();
    v27RuntimeState.startMilliseconds = startMilliseconds;

    if (environment.warning) {
        v27AddAnomaly(
            anomalies,
            "环境兼容提醒",
            environment.productLabel,
            environment.warning
        );
    }

    var scanRecords = [];
    var successRecords = [];
    var unclosedDocs = [];

    // 第一轮扫描：读取原稿属性和预警信息。
    for (var i = 0; i < files.length; i++) {
        var scanDoc = null;
        var scanFileName = decodeFileName(files[i]);
        var scanOldDialogs = app.displayDialogs;

        try {
            setSilentMode();
            scanDoc = app.open(files[i]);

            var sourcePPI = scanDoc.resolution;
            var scanICC = v27NormalizeICC(getICCProfile(scanDoc));

            scanRecords.push({
                fileName: scanFileName,
                sourcePPI: sourcePPI,
                dpi: getOutputDPI(sourcePPI),
                mode: getColorMode(scanDoc),
                icc: scanICC
            });

            if (sourcePPI < 150) {
                v27AddAnomaly(
                    anomalies,
                    "低PPI",
                    scanFileName,
                    "原始PPI为" + v27NumberText(sourcePPI) + "，低于150"
                );
            }

            if (sourcePPI > 1500) {
                v27AddAnomaly(
                    anomalies,
                    "高PPI",
                    scanFileName,
                    "原始PPI为" + v27NumberText(sourcePPI) + "，高于1500"
                );
            }

            if (scanICC == "ICC读取失败") {
                v27AddAnomaly(
                    anomalies,
                    "ICC读取失败",
                    scanFileName,
                    "无法读取原稿ICC配置"
                );
            }
        } catch (scanError) {
            v27AddAnomaly(
                anomalies,
                scanDoc ? "文件检测失败" : "文件打开失败",
                scanFileName,
                v27ErrorText(scanError)
            );
        } finally {
            v27TryCloseDocument(scanDoc, scanFileName, anomalies, unclosedDocs);

            try {
                restoreDialogMode(scanOldDialogs);
            } catch (dialogError) {
                v27AddAnomaly(
                    anomalies,
                    "Photoshop状态恢复失败",
                    scanFileName,
                    v27ErrorText(dialogError)
                );
            }
        }

        if ((i + 1) % 20 === 0) {
            v27CleanupMemory(scanFileName, anomalies);
        }
    }

    v27CleanupMemory("第一轮扫描结束", anomalies);

    // 第二轮输出：保持像素，修改物理尺寸并按原稿格式保存。
    for (var j = 0; j < files.length; j++) {
        var doc = null;
        var outputFileName = decodeFileName(files[j]);
        var oldDialogs = app.displayDialogs;
        var stage = "准备处理";

        updateProgress(j + 1, files.length, outputFileName);

        try {
            setSilentMode();
            stage = "打开文件";
            doc = app.open(files[j]);

            stage = "计算制作分辨率";
            var originalPPI = doc.resolution;
            var outputDPI = getOutputDPI(originalPPI);

            stage = "调整制作尺寸";
            doc.resizeImage(
                undefined,
                undefined,
                outputDPI,
                ResampleMethod.NONE
            );

            var widthCM = doc.width.as("cm");
            var heightCM = doc.height.as("cm");
            var outputMode = getColorMode(doc);
            var outputICC = v27NormalizeICC(getICCProfile(doc));
            var extension = v27OutputExtension(files[j]);
            var outputFile = v27VersionedOutputFile(
                outputFolder,
                v27BaseName(files[j]),
                extension
            );

            stage = extension == ".jpg" ? "保存JPG" : "保存TIFF";
            v27SaveProductionFile(doc, outputFile, extension);

            successRecords.push({
                sourceFileName: outputFileName,
                fileName: decodeFileName(outputFile),
                width: widthCM,
                height: heightCM,
                dpi: outputDPI,
                mode: outputMode,
                icc: outputICC,
                extension: extension
            });
            v27RuntimeState.successCount = successRecords.length;
        } catch (outputError) {
            v27AddAnomaly(
                anomalies,
                stage + "失败",
                outputFileName,
                v27ErrorText(outputError)
            );
        } finally {
            v27TryCloseDocument(doc, outputFileName, anomalies, unclosedDocs);

            try {
                restoreDialogMode(oldDialogs);
            } catch (restoreError) {
                v27AddAnomaly(
                    anomalies,
                    "Photoshop状态恢复失败",
                    outputFileName,
                    v27ErrorText(restoreError)
                );
            }
        }

        if ((j + 1) % 20 === 0) {
            v27CleanupMemory(outputFileName, anomalies);
        }
    }

    v27CleanupMemory("第二轮输出结束", anomalies);
    v27RetryUnclosedDocuments(unclosedDocs, anomalies);
    v27RegisterDifferenceAnomalies(successRecords, anomalies);

    var endTimeText = getChinaTime();
    var endMilliseconds = new Date().getTime();
    var elapsedSeconds = Math.round((endMilliseconds - startMilliseconds) / 1000);

    if (successRecords.length > 0) {
        var deliveryFile = v28VersionedTextFile(
            outputFolder,
            dateStamp + "_" + projectName + "_交付说明"
        );

        try {
            v27SafeWriteUTF8(
                deliveryFile,
                v27BuildDeliveryText(projectName, endTimeText, successRecords)
            );
        } catch (deliveryError) {
            v27AddAnomaly(
                anomalies,
                "交付说明写入失败",
                decodeFileName(deliveryFile),
                v27ErrorText(deliveryError)
            );
        }
    } else {
        v27AddAnomaly(
            anomalies,
            "未形成交付",
            projectName,
            "没有文件成功输出，因此未生成交付说明"
        );
    }

    var runLogResult = v28WriteRunLogSafely(
        dateStamp,
        elapsedSeconds,
        outputFolder
    );

    if (!runLogResult.file) {
        alert(
            "批处理已经结束，但运行日志写入失败。\n\n" +
            "原因：" + runLogResult.errorText
        );
    } else if (runLogResult.usedFallback) {
        alert(
            "桌面不可写，运行日志已保存到备用位置：\n" +
            runLogResult.file.fsName
        );
    }

    try {
        v28SetProgressText(
            "批处理完成：成功" + successRecords.length +
            "个，失败" + (files.length - successRecords.length) + "个"
        );
    } catch (statusError) {}
}


function v27RunSafely() {
    var originalDialogs = app.displayDialogs;

    try {
        runV27();
    } catch (fatalError) {
        var fatalReason = v27ErrorText(fatalError);

        v27AddAnomaly(
            v27RuntimeState.anomalies,
            "批处理意外终止",
            v27RuntimeState.projectName,
            fatalReason
        );

        if (v27RuntimeState.batchStarted) {
            try {
                app.displayDialogs = DialogModes.NO;

                while (app.documents.length > 0) {
                    app.activeDocument.close(SaveOptions.DONOTSAVECHANGES);
                }
            } catch (closeFatalError) {
                v27AddAnomaly(
                    v27RuntimeState.anomalies,
                    "批处理清理失败",
                    v27RuntimeState.projectName,
                    v27ErrorText(closeFatalError)
                );
            }
        }

        var emergencySeconds = v27RuntimeState.startMilliseconds > 0 ?
            Math.round(
                (new Date().getTime() - v27RuntimeState.startMilliseconds) / 1000
            ) :
            0;
        var emergencyLogResult = v28WriteRunLogSafely(
            v27DateStamp(),
            emergencySeconds,
            v27RuntimeState.outputFolder
        );

        if (emergencyLogResult.file) {
            alert(
                "批处理意外终止。\n\n" +
                "原因：" + fatalReason +
                "\n\n运行日志：" + emergencyLogResult.file.fsName
            );
        } else {
            alert(
                "批处理意外终止，并且无法写入运行日志。\n\n" +
                "原因：" + fatalReason +
                "\n日志错误：" + emergencyLogResult.errorText
            );
        }
    } finally {
        try {
            app.displayDialogs = originalDialogs;
        } catch (ignoreRestore) {}
    }
}


v27RunSafely();
