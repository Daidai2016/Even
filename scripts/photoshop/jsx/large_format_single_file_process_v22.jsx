#target photoshop

app.bringToFront();


// =================================
// 大画面输出助手 V22
//
// Photoshop 27.10兼容
//
// 图像尺寸放大10倍输出
//
// 功能：
// ppi ÷10
// 保持像素
// 跟随源文件格式：JPG 品质12/基线标准；TIFF 单图层/LZW/保留透明
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



function v20JoinPath(parent, leafName) {
    var base = "";
    // 每个名称单独编码，避免百分号、空格等字符被当作路径语法。
    var encodedLeaf = encodeURIComponent(String(leafName));

    try {
        base = parent.absoluteURI;
    } catch (absoluteURIError) {}

    if (!base) {
        base = String(parent);
    }

    if (base.charAt(base.length - 1) != "/") {
        base += "/";
    }

    return base + encodedLeaf;
}


function v20CheckWritableFolder(folder, diagnostic) {
    var probe;
    var probeName = "_even_single_v20_write_test_" + new Date().getTime();
    var suffix = 0;
    // 避开已有文件；清理时只处理本次检查创建的文件。
    do {
        probe = new File(v20JoinPath(folder, probeName + "_" + suffix + ".tmp"));
        suffix++;
    } while (probe.exists);

    var opened = false;
    var wrote = false;
    var closed = true;
    var removed = true;
    var errors = [];
    var stage = "创建测试文件";

    if (diagnostic) {
        diagnostic.errorText = "";
    }

    try {
        probe.encoding = "UTF-8";

        opened = probe.open("w");

        if (opened) {
            stage = "写入测试内容";
            wrote = probe.write("write-test") !== false;
            if (!wrote) {
                errors.push(stage + "失败：" + (probe.error || "未返回具体原因"));
            }
        } else {
            errors.push(stage + "失败：" + (probe.error || "未返回具体原因"));
        }
    } catch (e) {
        wrote = false;
        errors.push(stage + "失败：" + v20ErrorText(e));
    } finally {
        try {
            // ExtendScript File没有opened属性，必须使用open()的返回值。
            if (opened) {
                closed = probe.close() !== false;
                if (!closed) {
                    errors.push("关闭测试文件失败：" + (probe.error || "未返回具体原因"));
                }
            }
        } catch (closeError) {
            closed = false;
            errors.push("关闭测试文件失败：" + v20ErrorText(closeError));
        }

        try {
            if (opened && probe.exists) {
                removed = probe.remove() !== false && !probe.exists;
                if (!removed) {
                    errors.push("清理测试文件失败：" + (probe.error || "未返回具体原因") +
                        "\n测试文件：" + probe.fsName);
                }
            }
        } catch (removeError) {
            removed = false;
            errors.push("清理测试文件失败：" + v20ErrorText(removeError) +
                "\n测试文件：" + probe.fsName);
        }
    }

    if (diagnostic) {
        diagnostic.errorText = errors.join("\n");
    }
    return opened && wrote && closed && removed && !probe.exists;
}



function v20ErrorText(error) {
    return error && error.message ? error.message : String(error);
}

function v20WriteReport(file, text) {
    var opened = false;
    var existedBefore = file.exists;
    var failure = "";
    try {
        file.encoding = "UTF-8";
        opened = file.open("w");
        if (!opened) {
            throw new Error("无法打开报告：" + (file.error || "未返回具体原因"));
        }
        if (file.write("\uFEFF" + text) === false) {
            throw new Error("报告写入失败：" + (file.error || "未返回具体原因"));
        }
    } catch (writeError) {
        failure = v20ErrorText(writeError);
    } finally {
        if (opened) {
            try {
                if (file.close() === false) {
                    failure += (failure ? "；" : "") + "报告关闭失败：" + (file.error || "未返回具体原因");
                }
            } catch (closeError) {
                failure += (failure ? "；" : "") + "报告关闭失败：" + v20ErrorText(closeError);
            }
        }
    }
    if (!failure && (!file.exists || file.length <= 0)) {
        failure = "未生成有效报告";
    }
    if (failure) {
        // 只清理本次新建的未完成报告，不删除原有文件。
        if (!existedBefore && opened && file.exists) {
            try {
                if (file.remove() === false || file.exists) {
                    failure += "；无法清理未完成报告：" + file.fsName;
                }
            } catch (removeError) {
                failure += "；无法清理未完成报告：" + file.fsName + "（" + v20ErrorText(removeError) + "）";
            }
        }
        throw new Error(failure);
    }
}

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
        "请打开JPG或TIFF文件。"
    );


    exit();

}



var activeDoc =
app.activeDocument;

var outputExtension = /\.jpe?g$/i.test(activeDoc.name) ? ".jpg" :
    (/\.tiff?$/i.test(activeDoc.name) ? ".tif" : "");
if (!outputExtension) {
    alert("仅支持JPG/JPEG或TIF/TIFF源文件，请打开对应文件后重试。");
    exit();
}
var outputFormatName = outputExtension === ".jpg" ? "JPG" : "TIFF";
var outputFormatDescription = outputExtension === ".jpg" ?
    "JPG 品质12 / 基线标准" : "TIFF 单图层 / LZW无损压缩 / 保留透明";



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


"格式：" + outputFormatDescription;



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
// 输出位置检查（修改分辨率前完成）
// ===============================
var sourceFile;
try {
    sourceFile = activeDoc.fullName;
    if (!sourceFile || !sourceFile.exists) {
        throw new Error("源文件尚未保存或已移走");
    }
} catch (sourceError) {
    alert("无法确定源文件位置。\n请先保存当前文件，再运行输出助手。\n\n" + v20ErrorText(sourceError));
    exit();
}

var parentFolder = sourceFile.parent;
var projectName = decodeFileName(sourceFile.name).replace(/\.[^\.]+$/, "");
var outputFolder = new Folder(v20JoinPath(parentFolder, projectName + "_制作文件"));
var outputFile = new File(v20JoinPath(outputFolder, projectName + "_定稿" + outputExtension));
var reportFile = new File(v20JoinPath(outputFolder, projectName + "_输出报告.txt"));

try {
    if (!outputFolder.exists && !outputFolder.create()) {
        throw new Error("无法创建输出文件夹：" + (outputFolder.error || "未返回具体原因"));
    }
    if (!outputFolder.exists) {
        throw new Error("输出文件夹不存在");
    }
    var writeDiagnostic = {};
    if (!v20CheckWritableFolder(outputFolder, writeDiagnostic)) {
        throw new Error(writeDiagnostic.errorText);
    }
} catch (folderError) {
    alert("输出位置检查失败，尚未修改图像。\n\n" + outputFolder.fsName + "\n\n" +
        v20ErrorText(folderError) + "\n\n请确认目录的写入权限，或将源文件保存到可写位置后重试。");
    exit();
}

var existingOutputs = [];
if (outputFile.exists) { existingOutputs.push(outputFile.fsName); }
if (reportFile.exists) { existingOutputs.push(reportFile.fsName); }
if (existingOutputs.length && !confirm("以下输出文件已存在：\n\n" + existingOutputs.join("\n") + "\n\n是否覆盖？")) {
    exit();
}

// ===============================
// 修改ppi、保持像素，按源格式保存
// ===============================
var outputOptions;
if (outputExtension === ".jpg") {
    outputOptions = new JPEGSaveOptions();
    outputOptions.quality = 12;
    outputOptions.formatOptions = FormatOptions.STANDARDBASELINE;
    outputOptions.embedColorProfile = true;
} else {
    outputOptions = new TiffSaveOptions();
    outputOptions.imageCompression = TIFFEncoding.TIFFLZW;
    outputOptions.embedColorProfile = true;
    // 只保存可见合成图，保留透明；不合并或展平当前文档的源图层。
    outputOptions.layers = false;
    outputOptions.transparency = true;
}

try {
    activeDoc.resizeImage(undefined, undefined, outputPPI, ResampleMethod.NONE);
    activeDoc.saveAs(outputFile, outputOptions, true, Extension.LOWERCASE);
    if (!outputFile.exists || outputFile.length <= 0) {
        throw new Error("未生成有效的" + outputFormatName + "文件");
    }
} catch (saveError) {
    var restoreErrorText = "";
    try {
        activeDoc.resizeImage(undefined, undefined, sourcePPI, ResampleMethod.NONE);
    } catch (restoreError) {
        restoreErrorText = "\n原始分辨率恢复失败：" + v20ErrorText(restoreError);
    }
    alert(outputFormatName + "保存失败，未生成报告。\n\n" + outputFile.fsName + "\n\n" +
        v20ErrorText(saveError) + restoreErrorText + "\n\n若目标处留有文件，请检查其完整性后再使用。");
    exit();
}


// ===============================
// TXT报告
// ===============================


var reportText =

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
"_定稿"+
outputExtension+
"\n\n"+


"========================\n"+
"  联系作者：\n"+
"  huaping.woo@gmail.com"
;

try {
    v20WriteReport(reportFile, reportText);
} catch (reportError) {
    alert(outputFormatName + "已保存，但输出报告生成失败。\n\n报告位置：" + reportFile.fsName + "\n\n" + v20ErrorText(reportError));
    exit();
}

// ===============================
// 完成
// ===============================

// 图像与报告均已成功保存，关闭输入文档且不保存任何修改。
try {
    activeDoc.close(SaveOptions.DONOTSAVECHANGES);
} catch (closeError) {
    alert("图像和报告已保存，但输入文档未能关闭。\n请手动关闭并选择“不保存”。\n\n" + v20ErrorText(closeError));
}
