#target photoshop


app.bringToFront();



// ==================================================
// 大画面输出助手 V20.4.3
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