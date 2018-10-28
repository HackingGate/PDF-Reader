# HGPDFKit  [![GitHub license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/HackingGate/HGPDFKit/master/LICENSE)
Apple PDFKit extension in Swift

## Usage

#### UIScrollView

You can directely access pdfView's scrollView by

```
pdfView.scrollView?
```

#### Auto zoom

Auto zoom in or out

```
pdfView.autoZoomInOrOut(location: sender.location(in: "location you want to zoom"), animated: true)
```

Is it zoomed in?

```
pdfView.isZoomedIn
```

#### RTL (Right to Left)

Change to RTL

```
pdfView.transformViewForRTL(true, pdfThumbnailView)
```

Is it chnaged to RTL?

```
pdfView.isViewTransformedForRTL
```

## Requirement 

iOS 11.3  
Swift 4

## Acknowledgement 

#### BookReader
Website: [https://github.com/kishikawakatsumi/BookReader](https://github.com/kishikawakatsumi/BookReader)  
License: [MIT](https://github.com/kishikawakatsumi/BookReader/blob/master/LICENSE)

