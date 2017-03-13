FF = F.Form

FF.Image = {
    buildField: FF.buildFileOrImageField(FT.Image, FT.ImageItem)

    getInput: FF.File.getInput
}