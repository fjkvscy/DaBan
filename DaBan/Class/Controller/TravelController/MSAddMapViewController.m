//
//  MSAddMapViewController.m
//  DaBan
//
//  Created by qkm on 15-8-15.
//  Copyright (c) 2015年 QKM. All rights reserved.
//

#import "MSAddMapViewController.h"
#import <MAMapKit/MAMapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MAMapKit/MAUserLocation.h>
#import <MAMapKit/MAAnnotation.h>
#import <MAMapKit/MAAnnotationView.h>
#import <MAMapKit/MAMapServices.h>
#import <MAMapKit/MAMapView.h>
#import <AMapSearchKit/AMapSearchAPI.h>
#import "MSThird.h"
#import "MSAddLineModel.h"
#import "MSLineAddViewController.h"
#import "MSLineModel.h"

#import "MSSearchListView.h"


@interface MSAddMapViewController ()<MAMapViewDelegate,UITableViewDataSource,UITableViewDelegate,AMapSearchDelegate,MSSearchListViewDelegate,MSSearchListViewDataSource>
{
    MAMapView          *_mapView;
    AMapSearchAPI      *_search;
    BOOL               wasFound;
    UITableView        *mainTableView;
    NSMutableArray     *myArrays;
    NSMutableArray     *myCodeArrays;
    CLLocationDegrees  latitude;
    CLLocationDegrees  longitude;
    NSString           *myAdd;
    
    UIButton           *sureBtn;
    
    MSSearchListView   *searchView;
    
    NSString           *city;
    
    BOOL               isGeocode;
}

@end


@implementation MSAddMapViewController


-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    //    MAPointAnnotation *pointAnnotation = [[MAPointAnnotation alloc]init];
    //    [_mapView addAnnotation:pointAnnotation];
    //    [self pointAnnotation];
    
    [self navigationSerach];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addTopSearch];
    //搜索框的数据
    myArrays = [NSMutableArray array];
    //地址编码数据
    myCodeArrays = [NSMutableArray array];
    
    [MAMapServices sharedServices].apiKey = kMAPKey;
    _mapView = [[MAMapView alloc]init];
    _mapView.frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT-261.5);
    _mapView.showsUserLocation = YES;
    _mapView.delegate = self;
    //MAUserTrackingModeNone：不跟随用户位置，仅在地图上显示。
    //    MAUserTrackingModeFollow：跟随用户位置移动，并将定位点设置成地图中心点。
    //    MAUserTrackingModeFollowWithHeading：跟随用户的位置和角度移动。
    //    _mapView.center = CGPointMake(SCREEN_WIDTH/2, (SCREEN_HEIGHT-138)/2);
    _mapView.userTrackingMode = MAUserTrackingModeFollow;
    _mapView.customizeUserLocationAccuracyCircleRepresentation = YES;
    
    //    _mapView.zoomEnabled = NO;    //NO表示禁用缩放手势，YES表示开启
    //    _mapView.scrollEnabled = NO;    //NO表示禁用滑动手势，YES表示开启
    _mapView.rotateEnabled= NO;    //NO表示禁用旋转手势，YES表示开启
    _mapView.rotateCameraEnabled= NO;    //NO表示禁用倾斜手势，YES表示开启
    
    _mapView.showsCompass= NO; // 设置成NO表示关闭指南针；YES表示显示指南针
    
    //    _mapView.compassOrigin= CGPointMake(_mapView.compassOrigin.x, 22); //设置指南针位置
    
    //    [_mapView setUserTrackingMode: MAUserTrackingModeFollow animated:YES]; //地图跟着位置移动
    //    [_mapView setZoomLevel:16.1 animated:YES];
    
//        UITapGestureRecognizer *mTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapPress:)];
//    
//        [_mapView setUserInteractionEnabled:YES];
//        [_mapView addGestureRecognizer:mTap];
    
    
    [self.view addSubview:_mapView];
    
    UIImageView *iv = [[UIImageView alloc]init];
    iv.frame = CGRectMake(_mapView.frame.size.width/2-10,_mapView.frame.size.height/2-64, 20, 30);
    
    //    NSLog(@"--%f--%f",_mapView.frame.size.height,iv.frame.origin.y);
    iv.backgroundColor = [UIColor clearColor];
    if (self.pagTag == 1) {
        iv.image = [UIImage imageNamed:@"activity_location_icon.png"];
    }else{
        iv.image = [UIImage imageNamed:@"activity_location_icon.png"];
    }
    
    [_mapView addSubview:iv];
    
    
    
    _search = [[AMapSearchAPI alloc]initWithSearchKey:kMAPKey Delegate:self];
    _search.language = AMapSearchLanguage_zh_CN;
    
    
    AMapPlaceSearchRequest *poiRequest = [[AMapPlaceSearchRequest alloc] init];
    poiRequest.searchType = AMapSearchType_PlaceAround;
    poiRequest.location = [AMapGeoPoint locationWithLatitude:39.990459 longitude:116.481476];
    poiRequest.keywords = @"俏江南";
    // types属性表示限定搜索POI的类别，默认为：餐饮服务、商务住宅、生活服务
    // POI的类型共分为20种大类别，分别为：
    // 汽车服务、汽车销售、汽车维修、摩托车服务、餐饮服务、购物服务、生活服务、体育休闲服务、
    // 医疗保健服务、住宿服务、风景名胜、商务住宅、政府机构及社会团体、科教文化服务、
    // 交通设施服务、金融保险服务、公司企业、道路附属设施、地名地址信息、公共设施
    poiRequest.types = @[@"餐厅"];
    poiRequest.city = @[@"beijing"];
    poiRequest.requireExtension = YES;
    
    //    发起POI搜索
    [_search AMapPlaceSearch: poiRequest];
    
    
    [self drawTableView];
    
}


-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:YES];
    //每次退出该页面就删除cell中的确定按键
    [[NSUserDefaults standardUserDefaults]setInteger:1000 forKey:@"isRow"];
}

//当位置更新时，会进定位回调，通过回调函数，能获取到定位点的经纬度坐标，示例代码如下：
-(void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation{
    if (updatingLocation) {
        //取出当前位置的坐标
        //        NSLog(@"latitude : %f,longitude: %f",userLocation.coordinate.latitude,userLocation.coordinate.longitude);
    }
    //    latitude = userLocation.coordinate.latitude;
    //    longitude = userLocation.coordinate.longitude;
    //    static int i= 1;
    //    if (i==1) {
    ////        [self pointAnnotation];
    //    }
    //    i++;
    //    [self regeocodeSearchRequest];
    
   
}


- (void)tapPress:(UISwipeGestureRecognizer *)gestureRecognizer {
     NSLog(@"11");
    //    CGPoint touchPoint = [gestureRecognizer locationInView:_mapView];//这里touchPoint是点击的某点在地图控件中的位置
    //    CLLocationCoordinate2D touchMapCoordinate =
    //    [_mapView convertPoint:touchPoint toCoordinateFromView:_mapView];//这里touchMapCoordinate就是该点的经纬度了
    //    NSLog(@"touching %f,%f",touchMapCoordinate.latitude,touchMapCoordinate.longitude);
    
}

//地图 的中间位置
-(void)mapView:(MAMapView *)mapView regionDidChangeAnimated:(BOOL)animated{
    //

    CLLocationCoordinate2D centerCoordinate = mapView.region.center;
    latitude = centerCoordinate.latitude;
    longitude = centerCoordinate.longitude;
//    NSLog(@" regionDidChangeAnimated %f,%f",centerCoordinate.latitude, centerCoordinate.longitude);
    if (isGeocode ==NO){
        [self regeocodeSearchRequest];
    }
}

#pragma -mark
#pragma -mark regecode

//实现正向地理编码的回调函数
- (void)onGeocodeSearchDone:(AMapGeocodeSearchRequest *)request response:(AMapGeocodeSearchResponse *)response
{
    if(response.geocodes.count == 0)
    {
        return;
    }
    
    //通过AMapGeocodeSearchResponse对象处理搜索结果
    NSString *strGeocodes = @"";
    for (AMapGeocode *p in response.geocodes) {
        strGeocodes = [NSString stringWithFormat:@"geocode: %@",p.location];
        isGeocode = YES;
        [_mapView setCenterCoordinate:CLLocationCoordinate2DMake(p.location.latitude, p.location.longitude) animated:YES];
//        NSLog(@"Geocode: %@--%f--%f", strGeocodes,latitude,longitude);
    }
}



//逆地理编码
-(void)regeocodeSearchRequest{
    AMapReGeocodeSearchRequest *regeoRequest = [[AMapReGeocodeSearchRequest alloc]init
                                                ];
    regeoRequest.searchType = AMapSearchType_ReGeocode;
    // 中心点坐标
    regeoRequest.location = [AMapGeoPoint locationWithLatitude:latitude longitude:longitude];
    regeoRequest.radius = 3000; //[default = 1000]; 查询半径，单位：米
    regeoRequest.requireExtension = YES; //是否返回扩展信息，默认为 NO
    //发起逆地理编码
    [_search AMapReGoecodeSearch:regeoRequest];
}

//实现逆地理编码的回调函数
-(void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response{
    
    if (response.regeocode != nil) {
        //通过AMapReGeocodeSearchResponse对象处理搜索结果
        //        NSString *result = [NSString stringWithFormat:@"ReGeocode: %@ \n",response.regeocode];
        
        [myCodeArrays removeAllObjects];
        
        for (AMapPOI *poi in  response.regeocode.pois) {
            [myCodeArrays addObject:poi];
        }
        
        
        MSLineModel *model = [[MSLineModel alloc]init];
        model.districtCode = response.regeocode.addressComponent.district;
        model.township     = response.regeocode.addressComponent.township;
        model.street       = response.regeocode.addressComponent.streetNumber.street;
        model.number       = response.regeocode.addressComponent.streetNumber.number;
        city         = response.regeocode.addressComponent.city;
        model.building     = response.regeocode.addressComponent.building;
        myAdd  = [NSString stringWithFormat:@"%@%@%@%@",model.districtCode,model.township,model.street,model.number];
        NSLog(@"regeocode：---%@  ",response);

        

    }
    
    [mainTableView reloadData];
    
    
}



#pragma -mark
#pragma -mark 输入提示搜索
-(void)search{
    //构造AMapInputTipsSearchRequest对象，keywords为必选项，city为可选项
    AMapInputTipsSearchRequest *tipsRequest= [[AMapInputTipsSearchRequest alloc] init];
    tipsRequest.searchType = AMapSearchType_InputTips;
    NSLog(@"self.searchtext = %@",self.searchText.text);
    tipsRequest.keywords = self.searchText.text;
    tipsRequest.city = @[city];
    
    //发起输入提示搜索
    [_search AMapInputTipsSearch: tipsRequest];
    
}

//实现输入提示的回调函数
-(void)onInputTipsSearchDone:(AMapInputTipsSearchRequest*)request response:(AMapInputTipsSearchResponse *)response
{
    if(response.tips.count == 0)
    {
        return;
    }
    
    [myArrays removeAllObjects];
    
    //通过AMapInputTipsSearchResponse对象处理搜索结果
    //    NSString *strCount = [NSString stringWithFormat:@"count: %d", response.count];
    for (AMapTip *p in response.tips) {
        //        strtips = [NSString stringWithFormat:@"%@\n%@", strtips, p.description];
//        NSLog(@"log:%@",p);
        MSAddLineModel *model = [[MSAddLineModel alloc]init];
        model.name      = p.name;
        model.adcode    = p.adcode;
        model.district  = p.district;
        [myArrays addObject:model];
    }
    //    NSString *result = [NSString stringWithFormat:@"%@", strtips];
    //    NSLog(@"InputTips: %@", result);
    //
    //    [myArrays removeAllObjects];
//    NSLog(@"response: %@",response);
    [searchView.listView reloadData];
}

#pragma -mark
#pragma -mark 大头针
-(void)pointAnnotation{
    MAPointAnnotation *pointAnnotation = [[MAPointAnnotation alloc] init];
    pointAnnotation.coordinate = CLLocationCoordinate2DMake(latitude,longitude);
    
    pointAnnotation.title = @"方恒国际";
    pointAnnotation.subtitle = @"阜通东大街6号";
    
    [_mapView addAnnotation:pointAnnotation];
}

-(MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation{
    if ([annotation isKindOfClass:[MAPointAnnotation class]]) {
        static NSString *pointReuseIndentifier = @"pointReuseIndentifier";
        MAPinAnnotationView*annotationView = (MAPinAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndentifier];
        if (annotationView == nil)
        {
            annotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndentifier];
            //            annotationView.frame = CGRectMake(_mapView.frame.size.width/2-15, _mapView.frame.size.height/2-15, 30, 30);
        }
        annotationView.center = CGPointMake(_mapView.frame.size.width/2, _mapView.frame.size.height/2);
        //        annotationView.canShowCallout= YES;       //设置气泡可以弹出，默认为NO
        //        annotationView.animatesDrop = YES;        //设置标注动画显示，默认为NO
        //        annotationView.draggable = YES;        //设置标注可以拖动，默认为NO
        //        annotationView.pinColor = MAPinAnnotationColorPurple;
        //        if (self.pagTag == 1) {
        //            annotationView.image = [UIImage imageNamed:@"mapSearch-end.png"];
        //        }else{
        //            annotationView.image = [UIImage imageNamed:@"mapSearch-start.png"];
        //        }
        
        //        //设置中⼼心点偏移，使得标注底部中间点成为经纬度对应点
        //        annotationView.centerOffset = CGPointMake(0, -18);
        return annotationView;
    }
    return nil;
}

////实现POI搜索对应的回调函数
//- (void)onPlaceSearchDone:(AMapPlaceSearchRequest *)request response:(AMapPlaceSearchResponse *)response
//{
//    if(response.pois.count == 0)
//    {
//        return;
//    }
//
//    //通过AMapPlaceSearchResponse对象处理搜索结果
//    NSString *strCount = [NSString stringWithFormat:@"count: %d",response.count];
//    NSString *strSuggestion = [NSString stringWithFormat:@"Suggestion: %@", response.suggestion];
//    NSString *strPoi = @"";
//    for (AMapPOI *p in response.pois) {
//        strPoi = [NSString stringWithFormat:@"%@\nPOI: %@", strPoi, p.description];
//    }
//    NSString *result = [NSString stringWithFormat:@"%@ \n %@ \n %@", strCount, strSuggestion, strPoi];
//    NSLog(@"Place: %@", result);
//}



//
//- (void)mapView:(MAMapView *)mapView didAddAnnotationViews:(NSArray *)views
//{
//    MAAnnotationView *view = views[0];
//
//    // 放到该方法中用以保证userlocation的annotationView已经添加到地图上了。
//    if ([view.annotation isKindOfClass:[MAUserLocation class]])
//    {
//        MAUserLocationRepresentation *pre = [[MAUserLocationRepresentation alloc] init];
//        pre.fillColor = [UIColor colorWithRed:0.9 green:0.1 blue:0.1 alpha:0.3];
//        pre.strokeColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.9 alpha:1.0];
//        pre.image = [UIImage imageNamed:@"mapSearch-start@2x.png"];
//        pre.lineWidth = 3;
//        pre.lineDashPattern = @[@6, @3];
//
//        [_mapView updateUserLocationRepresentation:pre];
//
//        view.calloutOffset = CGPointMake(0, 0);
//    }
//}

-(void)navigationSerach{
    AMapNavigationSearchRequest *naviRequest= [[AMapNavigationSearchRequest alloc] init];
    naviRequest.searchType = AMapSearchType_NaviDrive;
    naviRequest.requireExtension = YES;
    naviRequest.origin = [AMapGeoPoint locationWithLatitude:latitude longitude:longitude];
    naviRequest.destination = [AMapGeoPoint locationWithLatitude:latitude longitude:longitude];
    
    //发起路径搜索
    [_search AMapNavigationSearch: naviRequest];
}

//实现路径搜索的回调函数
- (void)onNavigationSearchDone:(AMapNavigationSearchRequest *)request response:(AMapNavigationSearchResponse *)response
{
    if(response.route == nil)
    {
        return;
    }
    
    //通过AMapNavigationSearchResponse对象处理搜索结果
    NSString *route = [NSString stringWithFormat:@"Navi: %.2f", response.route.taxiCost];
//    NSLog(@"%@", route);
}

#pragma -mark
#pragma -mark 右导航栏按钮
-(void)voiceSearchButtonClickon:(UIButton *)paramBut
{
}

#pragma -mark
#pragma -mark TableViewDelegate
-(void)drawTableView{
    mainTableView = [[UITableView alloc]initWithFrame:CGRectMake(0, CGRectGetMaxY(_mapView.frame)-64
                                                                 
                                                                 , SCREEN_WIDTH, 52*5+1.5)];
    mainTableView.delegate = self;
    mainTableView.dataSource = self;
    mainTableView.backgroundColor = [UIColor whiteColor];
    mainTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    mainTableView.hidden = NO;
    [self.view addSubview:mainTableView];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    //    if (self.isFirst == YES) {
    return myCodeArrays.count;
    //    }else{
    
    //    }
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 52;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *cellIden = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIden];
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIden];
    }
    
    for (id subView in cell.contentView.subviews) {
        
        if ([subView isKindOfClass:[UIView class]]) {
            
            UIView *vie = (UIView *)subView;
            [vie removeFromSuperview];
        }
    }
//    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    AMapPOI *model = myCodeArrays[indexPath.row];
    
    
    UILabel *label = [[UILabel alloc]initWithFrame:CGRectMake(10, 10, SCREEN_WIDTH-80, 14)];
    label.backgroundColor = [UIColor clearColor];
    label.font = ZIFOUT14;
    label.textColor = ZICOLOR;
    label.text = model.name;
    [cell.contentView addSubview:label];
    
    //    详细的地址
    UILabel *arcelab = [[UILabel alloc]initWithFrame:CGRectMake(10, CGRectGetMaxY(label.frame)+8, SCREEN_WIDTH-80, 12)];
    arcelab.backgroundColor = [UIColor clearColor];
    arcelab.text = model.address;
    arcelab.font = [UIFont systemFontOfSize:12.0];
    arcelab.textColor = ZIGRAY;
    [cell.contentView addSubview:arcelab];
    
    
    sureBtn = [[UIButton alloc]initWithFrame:CGRectMake(cell.frame.size.width-80, (cell.frame.size.height-30)/2, 70, 30)];
    sureBtn.backgroundColor = [UIColor clearColor];
    [sureBtn setTitle:@"确定" forState:UIControlStateNormal];
    [sureBtn setTitleColor:APP_COLOR forState:UIControlStateNormal];
    sureBtn.tag = indexPath.row;
    [sureBtn addTarget:self action:@selector(sureBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    sureBtn.layer.cornerRadius = 2.0;
    [sureBtn.layer setBorderWidth:1.0];
    sureBtn.layer.borderColor = APP_COLOR.CGColor;
    if (sureBtn.tag == [[NSUserDefaults standardUserDefaults]integerForKey:@"isRow"]) {
        sureBtn.hidden = NO;
    }else{
        sureBtn.hidden = YES;
    }
    [cell.contentView addSubview:sureBtn];
    
    UILabel *line = [[UILabel alloc]initWithFrame:CGRectMake(0, 52-0.5, SCREEN_WIDTH, 0.5)];
    line.backgroundColor = LINEC;
    [cell.contentView addSubview:line];
    
    return cell;
}


-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    
    //cell当中的确定键
    
    [[NSUserDefaults standardUserDefaults]setInteger:indexPath.row forKey:@"isRow"];
    
    [tableView reloadData];
    
    isGeocode = YES;
    
    AMapPOI *model = myCodeArrays[indexPath.row];
    [_mapView setCenterCoordinate:CLLocationCoordinate2DMake(model.location.latitude, model.location.longitude) animated:YES];
    
    //构造AMapGeocodeSearchRequest对象，address为必选项，city为可选项
//    AMapGeocodeSearchRequest *geoRequest = [[AMapGeocodeSearchRequest alloc] init];
//    geoRequest.searchType = AMapSearchType_Geocode;
//    geoRequest.address = model.address;
////22.528444, 113.947075
//    geoRequest.city = @[city];
//    NSLog(@"ADDRESS: %@ ",model.address);
//    //正向地理编码
//    [_search AMapGeocodeSearch:geoRequest];
    
}

-(void)sureBtnClick :(UIButton *)sender{
    
    if (self.pagTag == 2) {
        if (sender.tag == 0) {
            MSLineModel *model = [[MSLineModel alloc]init];
            NSLog(@"---%@",model.districtCode);
            self.searchText.text = myAdd;
        }else{
            
            AMapPOI *model = myCodeArrays[sender.tag];
            self.searchText.text = model.name;
            
        }
        
    }else{
        
        AMapPOI *model = myCodeArrays[sender.tag];
        self.searchText.text = model.name;
        
    }
    
    if (self.pagTag == 1) {
        if (self.delegate&&[self.delegate respondsToSelector:@selector(addMapViewControllerDelegate:andTag:andlatitude:andLongitude:)]) {
            [self.delegate addMapViewControllerDelegate:self.searchText.text andTag:1 andlatitude:latitude andLongitude:longitude];
        }
        [self.navigationController popViewControllerAnimated:YES];
        
    }else{
        
        if (self.delegate&&[self.delegate respondsToSelector:@selector(addMapViewControllerDelegate:andTag:andlatitude:andLongitude:)]) {
            [self.delegate addMapViewControllerDelegate:self.searchText.text andTag:2 andlatitude:latitude andLongitude:longitude];;
        }
        [self.navigationController popViewControllerAnimated:YES];
        
    }

    
//    [self.navigationController popViewControllerAnimated:YES];
    
}

#pragma -mark



-(void)textFieldDidBeginEditing:(UITextField *)textField{
    [self search];
     NSLog(@"1 = %@",textField.text);
    searchView  = [[MSSearchListView alloc]initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT-62)];
    searchView.delegate = self;
    searchView.datasource = self;
    searchView.backgroundColor = LINEE;
    [self.view addSubview:searchView];
    
}

-(void)textFieldDidEndEditing:(UITextField *)textField{
    [self search];
}

- (BOOL)textField:(UITextField*)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    [self search];
    return YES;
}

-(NSInteger)serchListView:(MSSearchListView *)serchListView rowIn:(NSInteger)row{
    return myArrays.count;
}

-(UITableViewCell *)serchListView:(MSSearchListView *)serchListView cellForIndexPath:(NSIndexPath *)indexPath{
    static NSString *identifier = @"cell";
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    
    cell.backgroundColor = [UIColor clearColor];
    MSAddLineModel *model = myArrays[indexPath.row];
    
    UILabel *titleLab = [[UILabel alloc]initWithFrame:CGRectMake(10, 10, SCREEN_WIDTH-20, 14)];
    titleLab.backgroundColor = [UIColor clearColor];
    titleLab.font = ZIFOUT14;
    titleLab.textColor = ZICOLOR;
    titleLab.text = model.name;
    [cell.contentView addSubview:titleLab];
    
    UILabel *addrLab = [[UILabel alloc]initWithFrame:CGRectMake(10, CGRectGetMaxY(titleLab.frame)+8, SCREEN_WIDTH-20, 14)];
    addrLab.backgroundColor = [UIColor clearColor];
    addrLab.text = model.district;
    addrLab.font = [UIFont systemFontOfSize:12];
    addrLab.textColor = LINE9;
    [cell.contentView addSubview:addrLab];
    
    UILabel *label2 = [[UILabel alloc]initWithFrame:CGRectMake(0, 52-0.5, SCREEN_WIDTH, 0.5)];
    label2.backgroundColor = HEXCOLOR(0xcccccc);
    [cell.contentView addSubview:label2];
    cell.contentView.backgroundColor = [UIColor whiteColor];
    return cell;
}

//滑动cell放弃第一响应
-(void)serchListViewWillBeginDecelerating:(UIScrollView *)scrollView{
    [self.searchText resignFirstResponder];
}

-(void)serchListView:(MSSearchListView *)serchListView didSelectIndexPath:(NSIndexPath *)indexPath{
    
    //构造AMapGeocodeSearchRequest对象，address为必选项，city为可选项
    MSAddLineModel *model = myArrays[indexPath.row];
    self.searchText.text = model.name;
    
    
    AMapGeocodeSearchRequest *geoRequest = [[AMapGeocodeSearchRequest alloc] init];
    geoRequest.searchType = AMapSearchType_Geocode;
    geoRequest.address = model.name;
    geoRequest.city = @[city];
    
    //正向地理编码
    [_search AMapGeocodeSearch:geoRequest];
    
    
    [serchListView removeFromSuperview];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    //拿到地图视图的触摸事件 可以解决点击列表中的某一行刷新的问题
    if([self.view pointInside:[touch locationInView:_mapView] withEvent:nil]){
        isGeocode = NO;
    }
    [self.searchText resignFirstResponder];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
