#target photoshop


app.bringToFront();



// ==================================================
// 大画面输出助手 V27.0.0
//
// Photoshop 27.10
//
// 更新：
//
// 1. DPI智能检测
// 2. 尺寸智能检测
// 3. ICC智能检测
// 4. 色彩模式检测
// 5. ICC读取函数独立化
// 6. 输入/输出色彩模式分离
// 7. 增加高PPI异常提醒
// 8. 增加运行耗时
// 9. 优化运行日志
// 10. 批处理不中断
// 11. TIFF LZW输出
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


        return decodeURIComponent(
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


    var folder =

        Folder.selectDialog(

            title

        );





    if (

        folder == null

    ) {


        exit();


    }





    return folder;


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




        app.updateStatusBarMessage(


            "正在处理：" +

            current +

            " / " +

            total +

            "\n" +

            name


        );



    } catch (e) {}



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


    exit();


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



        outputFolder +

        "/" +

        inputFolderName +

        "_输出报告.txt"



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








        for (

            var r = 0;

            r < reportData.length;

            r++

        ) {




            reportText +=



                "  " +

                reportData[r].name +

                "\n" +

                "  " +

                reportData[r].width.toFixed(1) +

                " × " +

                reportData[r].height.toFixed(1) +

                " cm\n\n";



        }



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



        outputFolder +

        "/" +

        inputFolderName +

        "_输出报告.txt"



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



        Folder.desktop +

        "/" +

        inputFolderName +

        "_运行日志.txt"



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

    "even.woo@gmail.com\n";











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
// V27 稳定增强主流程
// ==================================================

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
        return decodeURIComponent(value);
    } catch (e) {
        return value;
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

    name = name.replace(/^\s*\d{8}[\s_\-]*/, "");
    name = name.replace(/[\s_\-]+(?:制作文件|输出文件|交付文件|转曲|定稿)$/i, "");
    name = name.replace(/[\s_\-]+v\d+(?:\.\d+)*$/i, "");
    name = name.replace(/^\s+|\s+$/g, "");

    if (!name) {
        name = original;
    }

    return v27SanitizeFilePart(name);
}


function v27BaseName(file) {
    return decodeFileName(file).replace(/\.(?:tif|tiff|jpg|jpeg)$/i, "");
}


function v27OutputExtension(file) {
    return /\.jpe?g$/i.test(file.name) ? ".jpg" : ".tif";
}


function v27GetProductionFiles(folder) {
    var files = folder.getFiles(function(f) {
        return f instanceof File && /\.(?:tif|tiff|jpg|jpeg)$/i.test(f.name);
    });

    files.sort(function(a, b) {
        var an = decodeFileName(a).toLowerCase();
        var bn = decodeFileName(b).toLowerCase();
        return an < bn ? -1 : (an > bn ? 1 : 0);
    });

    return files;
}


function v27VersionedOutputFile(folder, baseName, extension) {
    var first = new File(folder + "/" + baseName + "_定稿" + extension);

    if (!first.exists) {
        return first;
    }

    var version = 2;
    var candidate;

    do {
        var versionText = version < 10 ? "0" + version : String(version);
        candidate = new File(
            folder + "/" + baseName + "_定稿_v" + versionText + extension
        );
        version++;
    } while (candidate.exists);

    return candidate;
}


function v27PrepareOpenDocuments() {
    var previousDialogs = app.displayDialogs;

    try {
        app.displayDialogs = DialogModes.ALL;

        while (app.documents.length > 0) {
            var existingDoc = app.activeDocument;

            try {
                existingDoc.close(SaveOptions.SAVECHANGES);
            } catch (e) {
                alert(
                    "无法保存并关闭文档：\n" +
                    existingDoc.name +
                    "\n\n原因：" +
                    v27ErrorText(e) +
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
        folder + "/.__even_v27_write_test_" + new Date().getTime() + ".tmp"
    );

    try {
        probe.encoding = "UTF-8";

        if (!probe.open("w")) {
            return false;
        }

        probe.write("write-test");
        probe.close();
        probe.remove();
        return true;
    } catch (e) {
        try {
            if (probe.opened) {
                probe.close();
            }
        } catch (ignore) {}

        try {
            if (probe.exists) {
                probe.remove();
            }
        } catch (ignoreRemove) {}

        return false;
    }
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

        doc.saveAs(
            outputFile,
            tifOptions,
            true,
            Extension.LOWERCASE
        );
    }

    if (!outputFile.exists) {
        throw new Error("Photoshop未生成目标文件");
    }
}


function v27SafeWriteUTF8(file, text) {
    var opened = false;

    try {
        file.encoding = "UTF-8";
        opened = file.open("w");

        if (!opened) {
            throw new Error("无法打开文本文件进行写入");
        }

        if (!file.write("\uFEFF" + text)) {
            throw new Error("文本内容写入失败");
        }
    } finally {
        if (opened) {
            file.close();
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

    if (sizeGroups.length > 1) {
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

    if (dpiGroups.length > 1) {
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
    anomalies
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
    text += v27BuildAnomalyText(anomalies);
    text += "联系作者：\n";
    text += "even.woo@gmail.com\n\n\n";
    text += "                         by Even Woo\n";

    return text;
}


var v27RuntimeState = {
    projectName: "批处理",
    scannedCount: 0,
    successCount: 0,
    startMilliseconds: 0,
    anomalies: []
};


function runV27() {
    if (!v27PrepareOpenDocuments()) {
        return;
    }

    var startMilliseconds = new Date().getTime();
    v27RuntimeState.startMilliseconds = startMilliseconds;
    var inputFolder = selectFolder("请选择需要处理的TIFF或JPG文件夹");
    var outputParent = selectFolder("请选择输出位置");
    var projectName = v27ProjectName(inputFolder);
    v27RuntimeState.projectName = projectName;
    var dateStamp = v27DateStamp();
    var inputFolderName = v27DecodeName(inputFolder.name);
    var outputFolder = new Folder(
        outputParent + "/" + inputFolderName + "_制作文件"
    );

    if (!outputFolder.exists && !outputFolder.create()) {
        alert("无法创建输出文件夹：\n" + outputFolder.fsName);
        return;
    }

    if (!v27CheckWritableFolder(outputFolder)) {
        alert("输出文件夹无法写入：\n" + outputFolder.fsName);
        return;
    }

    var files = v27GetProductionFiles(inputFolder);
    v27RuntimeState.scannedCount = files.length;

    if (files.length === 0) {
        alert("没有找到TIFF或JPG文件");
        return;
    }

    var anomalies = [];
    v27RuntimeState.anomalies = anomalies;
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
    var deliveryFile = new File(
        outputFolder + "/" + dateStamp + "_" + projectName + "_交付说明.txt"
    );
    var runLogFile = new File(
        Folder.desktop + "/" + dateStamp + "_" + projectName + "_运行日志.txt"
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

    try {
        v27SafeWriteUTF8(
            runLogFile,
            v27BuildRunLogText(
                projectName,
                files.length,
                successRecords.length,
                elapsedSeconds,
                anomalies
            )
        );
    } catch (runLogError) {
        alert(
            "批处理已经结束，但运行日志写入失败。\n\n" +
            "目标文件：" + runLogFile.fsName +
            "\n原因：" + v27ErrorText(runLogError)
        );
    }

    try {
        app.updateStatusBarMessage(
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

        try {
            var emergencySeconds = v27RuntimeState.startMilliseconds > 0 ?
                Math.round(
                    (new Date().getTime() - v27RuntimeState.startMilliseconds) / 1000
                ) :
                0;
            var emergencyLog = new File(
                Folder.desktop + "/" +
                v27DateStamp() + "_" +
                v27SanitizeFilePart(v27RuntimeState.projectName) +
                "_运行日志.txt"
            );

            v27SafeWriteUTF8(
                emergencyLog,
                v27BuildRunLogText(
                    v27RuntimeState.projectName,
                    v27RuntimeState.scannedCount,
                    v27RuntimeState.successCount,
                    emergencySeconds,
                    v27RuntimeState.anomalies
                )
            );
        } catch (emergencyLogError) {
            alert(
                "批处理意外终止，并且无法写入桌面运行日志。\n\n" +
                "原因：" + fatalReason +
                "\n日志错误：" + v27ErrorText(emergencyLogError)
            );
        }
    } finally {
        try {
            app.displayDialogs = originalDialogs;
        } catch (ignoreRestore) {}
    }
}


v27RunSafely();
